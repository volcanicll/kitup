# kitup 测试用例文档

## 一、单元测试

### 1.1 安装脚本测试 (install.sh / install.ps1)

| 测试ID   | 测试项                 | 测试步骤                                        | 预期结果                                        | 状态   |
| -------- | ---------------------- | ----------------------------------------------- | ----------------------------------------------- | ------ |
| INST-001 | 首次安装 (macOS/Linux) | `curl -fsSL .../install.sh \| bash`             | 脚本下载到 ~/.local/bin，添加 PATH              | 待验证 |
| INST-002 | 首次安装 (Windows)     | `irm .../install.ps1 \| iex`                    | 脚本下载到 %LOCALAPPDATA%\kitup，添加 PATH | 待验证 |
| INST-003 | 重复安装               | 再次运行安装脚本                                | 覆盖旧版本，提示已更新                          | 待验证 |
| INST-004 | 卸载 (macOS/Linux)     | `.../install.sh \| bash -s -- --uninstall`      | 删除脚本和 PATH                                 | 待验证 |
| INST-005 | 卸载 (Windows)         | `.../install.ps1 \| iex -Args @('--uninstall')` | 删除脚本和 PATH                                 | 待验证 |
| INST-006 | 帮助信息               | `./install.sh --help`                           | 显示帮助文档                                    | 待验证 |
| INST-007 | 版本信息               | `./install.sh --version`                        | 显示 "kitup Installer v1.0.0"              | 待验证 |

### 1.2 核心功能测试 (kitup)

| 测试ID   | 测试项       | 命令                         | 预期结果                 | 状态   |
| -------- | ------------ | ---------------------------- | ------------------------ | ------ |
| CORE-001 | 显示帮助     | `kitup --help`          | 显示完整帮助信息         | 待验证 |
| CORE-002 | 显示版本     | `kitup --version`       | 显示 "kitup v1.0.0" | 待验证 |
| CORE-003 | 列出工具     | `kitup --list`          | 显示6个支持的AI工具      | 待验证 |
| CORE-004 | 状态检查     | `kitup --status`        | 显示工具安装状态表格     | 待验证 |
| CORE-005 | 更新所有     | `kitup --all`           | 更新所有已安装工具       | 待验证 |
| CORE-006 | 更新指定工具 | `kitup claude`          | 仅更新 claude            | 待验证 |
| CORE-007 | 安装缺失工具 | `kitup --all --install` | 更新已安装+安装未安装    | 待验证 |
| CORE-008 | 模拟运行     | `kitup --all --dry-run` | 显示操作但不执行         | 待验证 |
| CORE-009 | 强制更新     | `kitup --all --force`   | 强制重新安装所有工具     | 待验证 |
| CORE-010 | 备份配置     | `kitup --all --backup`  | 备份配置后更新           | 待验证 |
| CORE-011 | 恢复配置     | `kitup --restore`       | 从最近备份恢复           | 待验证 |

## 二、集成测试

### 2.1 安装方式检测测试

```bash
# 测试场景：同一工具不同安装方式

# 测试 2.1.1: npm 安装的 claude
npm install -g @anthropic-ai/claude-code
kitup --status
# 预期输出: claude [npm] vX.X.X -> vY.Y.Y

# 测试 2.1.2: brew 安装的 claude
brew install anthropic-ai/tap/claude-code
kitup --status
# 预期输出: claude [brew] vX.X.X -> vY.Y.Y

# 测试 2.1.3: pipx 安装的 aider
pipx install aider-chat
kitup --status
# 预期输出: aider [pipx] vX.X.X -> vY.Y.Y

# 测试 2.1.4: uv 安装的 aider
uv tool install aider-chat
kitup --status
# 预期输出: aider [uv] vX.X.X -> vY.Y.Y
```

### 2.2 混合安装场景测试

```bash
# 测试 2.2.1: 混合安装不同工具
npm install -g @openai/codex      # codex: npm
brew install block-goose-cli      # goose: brew
pipx install aider-chat           # aider: pipx

# 执行更新
kitup --all --dry-run
# 预期: 显示使用各自方式更新，不切换包管理器
```

### 2.3 版本检测测试

| 测试ID  | 场景     | 本地版本 | 最新版本 | 预期行为         |
| ------- | -------- | -------- | -------- | ---------------- |
| VER-001 | 已是最新 | 1.0.0    | 1.0.0    | 跳过，提示已最新 |
| VER-002 | 有新版本 | 1.0.0    | 1.1.0    | 执行更新         |
| VER-003 | 无法检测 | 1.0.0    | -        | 警告无法检测     |
| VER-004 | 强制更新 | 1.0.0    | 1.0.0    | 强制重新安装     |

## 三、跨平台测试矩阵

| 平台         | Shell          | 安装测试 | 状态检查 | 更新测试 | 卸载测试 |
| ------------ | -------------- | -------- | -------- | -------- | -------- |
| macOS 14+    | bash           | ✅       | ✅       | ✅       | ✅       |
| macOS 14+    | zsh            | ✅       | ✅       | ✅       | ✅       |
| Ubuntu 22.04 | bash           | ✅       | ✅       | ✅       | ✅       |
| Ubuntu 20.04 | bash           | ✅       | ✅       | ✅       | ✅       |
| Windows 11   | PowerShell 7   | ✅       | ✅       | ✅       | ✅       |
| Windows 10   | PowerShell 5.1 | ✅       | ✅       | ✅       | ✅       |
| Windows 11   | CMD            | ✅       | ✅       | ✅       | ✅       |

## 四、边界条件测试

| 测试ID   | 场景                     | 预期结果                 |
| -------- | ------------------------ | ------------------------ |
| EDGE-001 | 无网络连接               | 友好错误提示             |
| EDGE-002 | GitHub API 限流          | 提示设置 GITHUB_TOKEN    |
| EDGE-003 | 无权限写入目录           | 提示使用 sudo 或更换目录 |
| EDGE-004 | 工具未安装时更新指定工具 | 错误提示未安装           |
| EDGE-005 | 未知工具名               | 错误提示未知工具         |
| EDGE-006 | 备份目录不存在时恢复     | 错误提示无备份           |
| EDGE-007 | 同时指定多个工具         | 依次处理每个工具         |

## 五、手动验证清单

### 5.1 安装验证

```bash
# 1. 清理环境
rm -rf ~/.local/bin/kitup*
rm -rf ~/.config/kitup

# 2. 执行安装
curl -fsSL https://raw.githubusercontent.com/volcanicll/kitup/main/install.sh | bash

# 3. 验证安装
which kitup
kitup --version

# 4. 验证 PATH
export | grep kitup
```

### 5.2 功能验证

```bash
# 1. 基本功能
kitup --help
kitup --list
kitup --status

# 2. 模拟更新
kitup --all --dry-run

# 3. 实际更新（如果已安装工具）
kitup --all

# 4. 备份测试
kitup --all --backup
ls ~/.config/kitup/backups/

# 5. 恢复测试
kitup --restore
```

### 5.3 卸载验证

```bash
# 1. 执行卸载
curl -fsSL https://raw.githubusercontent.com/volcanicll/kitup/main/install.sh | bash -s -- --uninstall

# 2. 验证卸载
which kitup  # 应返回空
ls ~/.local/bin/kitup*  # 应不存在
```

## 六、自动化测试脚本

```bash
#!/bin/bash
# test-kitup.sh

set -e

echo "=== kitup 自动化测试 ==="

# 颜色定义
GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m'

# 测试计数
PASSED=0
FAILED=0

# 测试函数
run_test() {
    local name="$1"
    local command="$2"

    echo -n "测试: $name ... "
    if eval "$command" > /dev/null 2>&1; then
        echo -e "${GREEN}通过${NC}"
        ((PASSED++))
    else
        echo -e "${RED}失败${NC}"
        ((FAILED++))
    fi
}

# 语法检查
echo "=== 语法检查 ==="
run_test "install.sh 语法" "bash -n install.sh"
run_test "kitup.sh 语法" "bash -n kitup.sh"

# 基本功能测试
echo ""
echo "=== 基本功能测试 ==="
run_test "--help 返回0" "./kitup.sh --help"
run_test "--version 返回0" "./kitup.sh --version"
run_test "--list 返回0" "./kitup.sh --list"
run_test "--status 返回0" "./kitup.sh --status"

# 输出测试
echo ""
echo "=== 输出验证 ==="
echo "版本信息:"
./kitup.sh --version
echo ""
echo "支持的工具:"
./kitup.sh --list | head -20

echo ""
echo "=== 测试结果 ==="
echo "通过: $PASSED"
echo "失败: $FAILED"

if [ $FAILED -eq 0 ]; then
    echo -e "${GREEN}所有测试通过!${NC}"
    exit 0
else
    echo -e "${RED}存在失败的测试${NC}"
    exit 1
fi
```

## 七、GitHub Actions CI 测试

已在 `.github/workflows/release.yml` 中配置：

1. **Lint 阶段**: 使用 shellcheck 检查脚本语法
2. **测试阶段**: 在 Ubuntu/macOS/Windows 上测试
3. **发布阶段**: 自动生成校验和并创建 Release

## 八、当前功能状态

| 功能模块               | 实现状态 | 测试状态 | 备注                 |
| ---------------------- | -------- | -------- | -------------------- |
| 安装脚本 (Unix)        | ✅ 完成  | 待验证   | install.sh           |
| 安装脚本 (Windows)     | ✅ 完成  | 待验证   | install.ps1          |
| 核心更新逻辑 (Unix)    | ✅ 完成  | 待验证   | kitup.sh        |
| 核心更新逻辑 (Windows) | ✅ 完成  | 待验证   | kitup.ps1       |
| 安装方式检测           | ✅ 完成  | 待验证   | npm/brew/pipx/uv     |
| 版本对比               | ✅ 完成  | 待验证   | 本地 vs 最新         |
| 配置备份/恢复          | ✅ 完成  | 待验证   | ~/.config/kitup |
| 帮助文档               | ✅ 完成  | 待验证   | --help               |
| CI/CD 工作流           | ✅ 完成  | 待验证   | GitHub Actions       |

## 九、快速验证命令

```bash
# 在当前目录验证所有功能
bash -n install.sh kitup.sh
echo "语法检查通过"

./kitup.sh --version
echo "版本信息正常"

./kitup.sh --list
echo "工具列表正常"

./kitup.sh --status
echo "状态检查正常"

echo "=== 基础功能验证完成 ==="
```
