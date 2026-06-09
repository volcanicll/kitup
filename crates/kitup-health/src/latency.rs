//! 延迟测量工具

use crate::LatencyResult;

/// 对供应商端点做延迟测试
pub async fn measure_provider_latency(
    name: &str,
    api_base: &str,
    api_key: Option<&str>,
) -> LatencyResult {
    let client = reqwest::Client::builder()
        .timeout(std::time::Duration::from_secs(10))
        .build();

    let client = match client {
        Ok(c) => c,
        Err(e) => {
            return LatencyResult {
                endpoint: api_base.to_string(),
                name: name.to_string(),
                latency_ms: None,
                http_status: None,
                error: Some(e.to_string()),
            };
        }
    };

    let start = std::time::Instant::now();

    let mut request = client
        .get(api_base)
        .header("User-Agent", "kitup");

    if let Some(key) = api_key {
        request = request.header("Authorization", format!("Bearer {}", key));
    }

    match request.send().await {
        Ok(resp) => {
            let elapsed = start.elapsed();
            LatencyResult {
                endpoint: api_base.to_string(),
                name: name.to_string(),
                latency_ms: Some(elapsed.as_millis() as u64),
                http_status: Some(resp.status().as_u16()),
                error: None,
            }
        }
        Err(e) => LatencyResult {
            endpoint: api_base.to_string(),
            name: name.to_string(),
            latency_ms: None,
            http_status: None,
            error: Some(e.to_string()),
        },
    }
}

/// 批量测速并生成报告
pub async fn benchmark_endpoints(
    endpoints: &[(String, String, Option<String>)], // (name, url, api_key)
) -> Vec<LatencyResult> {
    let mut handles = Vec::new();

    for (name, url, key) in endpoints {
        let name = name.clone();
        let url = url.clone();
        let key = key.clone();
        handles.push(tokio::spawn(async move {
            measure_provider_latency(&name, &url, key.as_deref()).await
        }));
    }

    let mut results = Vec::new();
    for handle in handles {
        if let Ok(result) = handle.await {
            results.push(result);
        }
    }

    results.sort_by_key(|r| r.latency_ms.unwrap_or(u64::MAX));
    results
}
