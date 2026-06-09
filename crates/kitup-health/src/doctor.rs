//! 诊断系统

use crate::checker;
use crate::{CheckCategory, CheckResult, CheckStatus};

/// 运行完整诊断
pub async fn run_diagnostics(fix: bool, verbose: bool) -> Vec<CheckResult> {
    let mut results = checker::run_system_checks().await;

    // 如果 fix 模式，尝试自动修复
    if fix {
        let mut fixed = Vec::new();
        for result in &results {
            if result.fixable && result.status == CheckStatus::Error {
                match result.category {
                    CheckCategory::Config => {
                        if let Ok(path) = kitup_core::config::Config::init() {
                            fixed.push(CheckResult {
                                name: "Configuration fix".to_string(),
                                category: CheckCategory::Config,
                                status: CheckStatus::Ok,
                                message: format!("Created default config: {}", path.to_string_lossy()),
                                suggestion: None,
                                fixable: false,
                                latency_ms: None,
                            });
                        }
                    }
                    _ => {}
                }
            }
        }
        results.extend(fixed);
    }

    // 如果不是 verbose，过滤掉 OK 的包管理器检查
    if !verbose {
        results.retain(|r| {
            r.status != CheckStatus::Ok || !matches!(r.category, CheckCategory::PackageManager)
        });
    }

    results
}

/// 生成诊断摘要
pub fn summarize(results: &[CheckResult]) -> DiagnosticSummary {
    let total = results.len();
    let errors = results.iter().filter(|r| r.status == CheckStatus::Error).count();
    let warnings = results.iter().filter(|r| r.status == CheckStatus::Warn).count();
    let ok = results.iter().filter(|r| r.status == CheckStatus::Ok).count();
    let fixable = results.iter().filter(|r| r.fixable).count();

    DiagnosticSummary {
        total,
        ok,
        warnings,
        errors,
        fixable,
    }
}

#[derive(Debug)]
pub struct DiagnosticSummary {
    pub total: usize,
    pub ok: usize,
    pub warnings: usize,
    pub errors: usize,
    pub fixable: usize,
}

impl std::fmt::Display for DiagnosticSummary {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        write!(
            f,
            "{} checks: {} ok, {} warnings, {} errors ({} fixable)",
            self.total, self.ok, self.warnings, self.errors, self.fixable
        )
    }
}
