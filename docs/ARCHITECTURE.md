# Kitup 架构文档

## 概述

Kitup 是一个统一的跨平台 AI 编码助手更新工具，采用单体仓库（monorepo）结构，使用 Turborepo 和 pnpm 管理。

## 项目结构

```
kitup/
├── packages/
│   ├── cli/                    # CLI 工具（Shell 脚本）
│   │   ├── kitup.sh           # Unix/Linux/macOS 实现
│   │   ├── kitup.ps1          # Windows PowerShell 实现
│   │   ├── kitup              # Unix 统一入口
│   │   ├── kitup.bat          # Windows 统一入口
│   │   ├── install.sh         # Unix 安装程序
│   │   ├── install.ps1        # Windows 安装程序
│   │   ├── test-regression.sh # 回归测试
│   │   ├── test-unit.sh       # 单元测试
│   │   └── package.json
│   │
│   └── website/               # 官方网站（Next.js）
│       ├── src/app/
│       │   ├── page.tsx       # 主页
│       │   ├── layout.tsx     # 布局
│       │   └── globals.css    # 样式
│       ├── dist/              # 构建输出
│       └── package.json
│
├── .github/workflows/          # CI/CD 配置
│   ├── cli-release.yml        # CLI 发布
│   └── website-deploy.yml     # 网站部署
│
├── turbo.json                 # Turborepo 配置
├── pnpm-workspace.yaml        # pnpm 工作区配置
├── package.json               # 根 package.json
├── CHANGELOG.md              # 变更日志
├── CONTRIBUTING.md           # 贡献指南
└── README.md                 # 项目说明
```

## 核心组件

### 1. CLI 工具

#### 双平台实现

Kitup 为不同平台提供了独立的实现：

- **Unix/Linux/macOS**: `kitup.sh` (Bash 脚本)
- **Windows**: `kitup.ps1` (PowerShell 脚本)

两个实现保持功能对等，但针对各自平台优化。

#### 统一入口点

- **Unix**: `kitup` 脚本检测环境并调用 `kitup.sh`
- **Windows**: `kitup.bat` 调用 PowerShell 执行 `kitup.ps1`

### 2. 工具定义系统

#### 数据结构

工具定义遵循以下格式：

**Shell 脚本格式**：
```bash
"name|command|npm_package|brew_formula|pipx_package|uv_package|github_repo|install_url"
```

**PowerShell 格式**：
```powershell
@("Name", "Command", "NpmPackage", "BrewFormula", "PipxPackage", "UvPackage", "GitHubRepo", "InstallUrl", "ChocoPackage", "ScoopPackage")
```

#### 支持的包管理器

| 平台 | 包管理器 |
|------|----------|
| 通用 | npm, pipx, uv, standalone |
| macOS/Linux | Homebrew |
| Windows | Chocolatey, Scoop |

### 3. PATH 感知检测

Kitup 的核心特性是 PATH 感知更新，确保使用与当前 PATH 中相同的安装方法进行更新。

#### 检测优先级

1. **PATH 优先**: 检查当前 PATH 中命令的实际位置
2. **包管理器匹配**: 根据路径判断安装方法
3. **回退检测**: 如果 PATH 无法确定，检查所有包管理器

#### 检测逻辑

```bash
# 1. 获取命令路径
tool_path=$(get_command_path "$cmd")

# 2. 检查是否在 npm 全局路径
if [[ "$tool_path" == "$npm_prefix/bin/"* ]]; then
    method="npm"
# 3. 检查是否在 Homebrew 路径
elif [[ "$tool_path" == "$brew_prefix/bin/"* ]]; then
    method="brew"
# 4. 检查是否在独立安装路径
elif is_standalone_path "$tool_path"; then
    method="standalone"
fi
```

### 4. 版本管理

#### 版本获取

Kitup 从多个来源获取版本信息：

| 安装方法 | 版本来源 |
|----------|----------|
| npm | npm registry API |
| Homebrew | brew info --json |
| pipx/uv | PyPI JSON API |
| standalone | GitHub releases API |

#### 版本比较

使用语义化版本比较：
- 提取主版本号：`x.y.z`
- 逐位比较：major > minor > patch
- 支持预发布版本：`x.y.z-alpha`

#### 自更新检查

Kitup 定期检查自身更新：

- **缓存机制**: 24小时 TTL，避免频繁检查
- **缓存位置**: `~/.config/kitup/self_update_check`
- **GitHub API**: 查询最新发布版本

### 5. 配置备份/恢复

#### 备份路径

支持备份的配置路径：
- `~/.claude` - Claude Code 配置
- `~/.config/opencode` - OpenCode 配置
- `~/.config/codex` - Codex 配置
- `~/.config/gemini` - Gemini CLI 配置
- `~/.config/goose` - Goose 配置
- `~/.aider.conf.yml` - Aider 配置
- `~/.config/cursor` - Cursor 配置
- `~/.config/windsurf` - Windsurf 配置
- `~/.config/tabby` - Tabby 配置
- `~/.config/continue` - Continue 配置

#### 备份机制

```bash
# 创建带时间戳的备份目录
backup_dir="$HOME/.config/kitup/backups/$(date +%Y%m%d_%H%M%S)"

# 复制配置文件
cp -r "$config_path" "$backup_dir/"

# 记录备份位置
echo "$backup_dir" > "$HOME/.config/kitup/last_backup"
```

### 6. 测试架构

#### 测试类型

1. **单元测试** (`test-unit.sh`)
   - 测试独立函数
   - 版本解析函数
   - 版本比较函数
   - 不依赖外部命令

2. **回归测试** (`test-regression.sh`)
   - 测试完整用户流程
   - 使用模拟命令
   - PATH 优先级测试
   - 配置备份/恢复测试

#### 模拟命令系统

使用 stub 命令模拟外部工具：

```bash
make_stub() {
    local path="$1"
    local content="$2"
    cat > "$path" <<EOF
#!/bin/bash
$content
EOF
    chmod +x "$path"
}
```

### 7. CI/CD 流水线

#### CLI 发布流程

1. 触发条件：创建 git tag
2. 构建步骤：
   - 运行测试
   - 语法检查（ShellCheck/PowerShell ScriptAnalyzer）
   - 创建 GitHub Release
3. 发布产物：
   - 原始脚本文件
   - 安装程序

#### 网站部署流程

1. 触发条件：推送到 main 分支
2. 构建步骤：
   - 安装依赖
   - 构建网站
   - 部署到 GitHub Pages

## 数据流图

```
用户输入
   ↓
参数解析
   ↓
工具查找 → 工具定义 (TOOLS 数组)
   ↓
版本检测 → 本地版本 + 最新版本
   ↓
更新决策 → 需要更新?
   ↓
配置备份 → (--backup)
   ↓
执行更新 → 根据安装方法
   ↓
结果输出 → 成功/失败/跳过
```

## 错误处理

### 错误类型

1. **命令不存在**: 提示使用 `--install` 安装
2. **版本检测失败**: 警告并跳过
3. **更新失败**: 显示错误并继续
4. **多个安装**: 警告并提供选项

### 退出码

- `0`: 成功
- `1`: 错误发生

## 扩展指南

### 添加新工具

1. 更新 `TOOLS` 数组（两个平台）
2. 添加配置备份路径
3. 添加测试用例
4. 更新文档

### 添加新包管理器

1. 实现 `get_xxx_latest_version()` 函数
2. 更新 `detect_install_method()` 函数
3. 更新 `update_tool()` 函数
4. 添加测试

## 性能考虑

- **顺序更新**: 当前逐个更新工具
- **API 缓存**: 自更新检查有 24 小时缓存
- **版本检测**: 只在需要时检测版本

## 安全考虑

- **不存储敏感信息**: 配置备份可能包含 API 密钥
- **不修改系统路径**: 仅更新用户安装的工具
- **干运行模式**: `--dry-run` 预览更改
- **备份机制**: 更新前备份配置

## 未来改进

- 并行更新工具
- 配置文件支持
- 版本固定功能
- 回滚功能
- 桌面通知
