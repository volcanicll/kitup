//! kitup-health: 健康检查和诊断
//!
//! API 连通性测试、延迟测量、自动诊断修复

use serde::{Deserialize, Serialize};

pub mod checker;
pub mod doctor;
pub mod latency;

/// 健康检查结果
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct CheckResult {
    pub name: String,
    pub category: CheckCategory,
    pub status: CheckStatus,
    pub message: String,
    #[serde(default)]
    pub suggestion: Option<String>,
    #[serde(default)]
    pub fixable: bool,
    pub latency_ms: Option<u64>,
}

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq)]
pub enum CheckCategory {
    Tool,
    PackageManager,
    Network,
    Config,
    System,
}

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq)]
pub enum CheckStatus {
    Ok,
    Warn,
    Error,
}

/// 延迟测试结果
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct LatencyResult {
    pub endpoint: String,
    pub name: String,
    pub latency_ms: Option<u64>,
    pub http_status: Option<u16>,
    pub error: Option<String>,
}

impl LatencyResult {
    pub fn is_ok(&self) -> bool {
        self.error.is_none() && self.latency_ms.is_some()
    }

    /// 获取延迟等级图标
    pub fn status_icon(&self) -> &str {
        match self.latency_ms {
            Some(ms) if ms < 200 => "🟢",
            Some(ms) if ms < 1000 => "🟡",
            Some(_) => "🔴",
            None => "⚫",
        }
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_latency_result_ok() {
        let result = LatencyResult {
            endpoint: "https://api.example.com".to_string(),
            name: "test".to_string(),
            latency_ms: Some(150),
            http_status: Some(200),
            error: None,
        };
        assert!(result.is_ok());
        assert_eq!(result.status_icon(), "🟢");
    }

    #[test]
    fn test_latency_result_error() {
        let result = LatencyResult {
            endpoint: "https://api.example.com".to_string(),
            name: "test".to_string(),
            latency_ms: None,
            http_status: None,
            error: Some("timeout".to_string()),
        };
        assert!(!result.is_ok());
        assert_eq!(result.status_icon(), "⚫");
    }

    #[test]
    fn test_latency_result_slow() {
        let result = LatencyResult {
            endpoint: "https://api.example.com".to_string(),
            name: "test".to_string(),
            latency_ms: Some(2500),
            http_status: Some(200),
            error: None,
        };
        assert!(result.is_ok());
        assert_eq!(result.status_icon(), "🔴");
    }
}
