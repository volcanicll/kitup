//! 故障转移队列管理

use crate::ProviderHealth;
use serde::{Deserialize, Serialize};
use std::time::{Duration, SystemTime};

/// 故障转移配置
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct FailoverConfig {
    pub enabled: bool,
    pub max_retries: u32,
    #[serde(default = "default_retry_delay")]
    pub retry_delay_secs: u64,
    #[serde(default = "default_failure_threshold")]
    pub failure_threshold: u32,
    #[serde(default = "default_reset_timeout")]
    pub reset_timeout_secs: u64,
}

fn default_retry_delay() -> u64 { 5 }
fn default_failure_threshold() -> u32 { 3 }
fn default_reset_timeout() -> u64 { 300 }

impl Default for FailoverConfig {
    fn default() -> Self {
        Self {
            enabled: false,
            max_retries: 3,
            retry_delay_secs: 5,
            failure_threshold: 3,
            reset_timeout_secs: 300,
        }
    }
}

/// 供应商熔断器状态
#[derive(Debug, Clone)]
pub struct CircuitBreaker {
    pub provider_name: String,
    pub consecutive_failures: u32,
    pub is_open: bool,
    pub last_failure: Option<SystemTime>,
    pub last_success: Option<SystemTime>,
}

impl CircuitBreaker {
    pub fn new(provider_name: &str) -> Self {
        Self {
            provider_name: provider_name.to_string(),
            consecutive_failures: 0,
            is_open: false,
            last_failure: None,
            last_success: None,
        }
    }

    /// 记录成功
    pub fn record_success(&mut self) {
        self.consecutive_failures = 0;
        self.is_open = false;
        self.last_success = Some(SystemTime::now());
    }

    /// 记录失败
    pub fn record_failure(&mut self, threshold: u32, _reset_timeout: Duration) {
        self.consecutive_failures += 1;
        self.last_failure = Some(SystemTime::now());

        if self.consecutive_failures >= threshold {
            self.is_open = true;
        }
    }

    /// 检查是否允许请求（半开状态）
    pub fn allow_request(&self, reset_timeout: Duration) -> bool {
        if !self.is_open {
            return true;
        }

        // 检查是否过了冷却期
        if let Some(last) = self.last_failure {
            if let Ok(elapsed) = SystemTime::now().duration_since(last) {
                return elapsed > reset_timeout;
            }
        }

        false
    }

    /// 获取健康状态
    pub fn health(&self) -> ProviderHealth {
        if self.is_open {
            ProviderHealth::Down
        } else if self.consecutive_failures > 0 {
            ProviderHealth::Degraded
        } else {
            ProviderHealth::Ok
        }
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_circuit_breaker_new() {
        let cb = CircuitBreaker::new("test");
        assert!(!cb.is_open);
        assert_eq!(cb.consecutive_failures, 0);
    }

    #[test]
    fn test_circuit_breaker_trips() {
        let mut cb = CircuitBreaker::new("test");
        for _ in 0..3 {
            cb.record_failure(3, Duration::from_secs(300));
        }
        assert!(cb.is_open);
        assert!(!cb.allow_request(Duration::from_secs(300)));
    }

    #[test]
    fn test_circuit_breaker_resets() {
        let mut cb = CircuitBreaker::new("test");
        for _ in 0..3 {
            cb.record_failure(3, Duration::from_secs(300));
        }
        assert!(cb.is_open);
        cb.record_success();
        assert!(!cb.is_open);
        assert!(cb.allow_request(Duration::from_secs(300)));
    }
}
