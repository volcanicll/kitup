//! kitup-core: AI 编码工具统一更新器核心库

pub mod config;
pub mod installer;
pub mod pin;
pub mod self_update;
pub mod tool;
pub mod version;

use anyhow::Result;
use std::path::Path;

/// Atomically write a file: write to a sibling temp file, then rename over
/// the destination so a crash never leaves a truncated config behind.
pub fn atomic_write(path: &Path, content: &str) -> Result<()> {
    if let Some(parent) = path.parent() {
        std::fs::create_dir_all(parent)?;
    }
    let tmp = path.with_extension("tmp");
    std::fs::write(&tmp, content)?;
    std::fs::rename(&tmp, path)?;
    Ok(())
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_atomic_write() {
        let dir = std::env::temp_dir().join(format!("kitup-test-{}", std::process::id()));
        let path = dir.join("nested").join("file.json");
        atomic_write(&path, "{\"a\":1}").unwrap();
        assert_eq!(std::fs::read_to_string(&path).unwrap(), "{\"a\":1}");
        atomic_write(&path, "{\"a\":2}").unwrap();
        assert_eq!(std::fs::read_to_string(&path).unwrap(), "{\"a\":2}");
        assert!(!path.with_extension("tmp").exists());
        std::fs::remove_dir_all(&dir).unwrap();
    }
}
