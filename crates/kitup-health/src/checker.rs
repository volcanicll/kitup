//! 健康检查引擎

use crate::{CheckCategory, CheckResult, CheckStatus, LatencyResult};
use anyhow::Result;

/// 端点健康检查
pub async fn check_endpoint(
    name: &str,
    url: &str,
    timeout_secs: u64,
) -> LatencyResult {
    let client = reqwest::Client::builder()
        .timeout(std::time::Duration::from_secs(timeout_secs))
        .build();

    match client {
        Ok(client) => {
            let start = std::time::Instant::now();
            match client
                .get(url)
                .header("User-Agent", "kitup")
                .send()
                .await
            {
                Ok(resp) => {
                    let elapsed = start.elapsed();
                    LatencyResult {
                        endpoint: url.to_string(),
                        name: name.to_string(),
                        latency_ms: Some(elapsed.as_millis() as u64),
                        http_status: Some(resp.status().as_u16()),
                        error: None,
                    }
                }
                Err(e) => LatencyResult {
                    endpoint: url.to_string(),
                    name: name.to_string(),
                    latency_ms: None,
                    http_status: None,
                    error: Some(e.to_string()),
                },
            }
        }
        Err(e) => LatencyResult {
            endpoint: url.to_string(),
            name: name.to_string(),
            latency_ms: None,
            http_status: None,
            error: Some(e.to_string()),
        },
    }
}

/// 批量检查多个端点
pub async fn check_endpoints(
    endpoints: &[(&str, &str)],
    timeout_secs: u64,
) -> Vec<LatencyResult> {
    let mut handles = Vec::new();

    for (name, url) in endpoints {
        let name = name.to_string();
        let url = url.to_string();
        handles.push(tokio::spawn(async move { check_endpoint(&name, &url, timeout_secs).await }));
    }

    let mut results = Vec::new();
    for handle in handles {
        if let Ok(result) = handle.await {
            results.push(result);
        }
    }

    // 按延迟排序
    results.sort_by_key(|r| r.latency_ms.unwrap_or(u64::MAX));
    results
}

/// 系统诊断检查
pub async fn run_system_checks() -> Vec<CheckResult> {
    let mut results = Vec::new();

    // 1. 配置文件检查
    match kitup_core::config::Config::load() {
        Ok(_) => {
            results.push(CheckResult {
                name: "Configuration".to_string(),
                category: CheckCategory::Config,
                status: CheckStatus::Ok,
                message: "Configuration file is valid".to_string(),
                suggestion: None,
                fixable: false,
                latency_ms: None,
            });
        }
        Err(e) => {
            results.push(CheckResult {
                name: "Configuration".to_string(),
                category: CheckCategory::Config,
                status: CheckStatus::Error,
                message: format!("Configuration error: {}", e),
                suggestion: Some("Run 'kitup config' to create default configuration".to_string()),
                fixable: true,
                latency_ms: None,
            });
        }
    }

    // 2. 包管理器检查
    for (cmd, name) in [("npm", "npm"), ("brew", "Homebrew"), ("pipx", "pipx"), ("uv", "uv")] {
        if which::which(cmd).is_ok() {
            results.push(CheckResult {
                name: format!("{} available", name),
                category: CheckCategory::PackageManager,
                status: CheckStatus::Ok,
                message: format!("{} is installed", name),
                suggestion: None,
                fixable: false,
                latency_ms: None,
            });
        }
    }

    // 3. 网络连通性
    let endpoints = [
        ("npm registry", "https://registry.npmjs.org/"),
        ("GitHub API", "https://api.github.com/"),
        ("PyPI", "https://pypi.org/"),
    ];

    let net_results = check_endpoints(&endpoints, 5).await;
    for result in net_results {
        let status = if result.error.is_some() {
            CheckStatus::Error
        } else if result.latency_ms.unwrap_or(0) > 2000 {
            CheckStatus::Warn
        } else {
            CheckStatus::Ok
        };

        results.push(CheckResult {
            name: result.name.clone(),
            category: CheckCategory::Network,
            status,
            message: match (&result.latency_ms, &result.error) {
                (Some(ms), None) => format!("Reachable ({}ms)", ms),
                (_, Some(e)) => format!("Unreachable: {}", e),
                _ => "Unknown".to_string(),
            },
            suggestion: result.error.as_ref().map(|_| "Check network connection".to_string()),
            fixable: false,
            latency_ms: result.latency_ms,
        });
    }

    // 4. 工具多安装检测
    for tool in kitup_core::tool::TOOL_REGISTRY {
        if which::which(tool.command).is_ok() {
            let all_methods = kitup_core::installer::detect_all_install_methods(tool).await;
            if all_methods.len() > 1 {
                results.push(CheckResult {
                    name: format!("{} multiple installs", tool.name),
                    category: CheckCategory::Tool,
                    status: CheckStatus::Warn,
                    message: format!(
                        "{} has {} installations: {}",
                        tool.name,
                        all_methods.len(),
                        all_methods.iter().map(|m| m.to_string()).collect::<Vec<_>>().join(", ")
                    ),
                    suggestion: Some("Clean up old installations, keep only one".to_string()),
                    fixable: false,
                    latency_ms: None,
                });
            }
        }
    }

    results
}
