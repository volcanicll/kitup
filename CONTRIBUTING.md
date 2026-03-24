# Contributing to Kitup

感谢您对 Kitup 的贡献兴趣！本文档将帮助您开始贡献。

## 开发环境设置

### 前置要求

- **Unix/Linux/macOS**: Bash 4.0+
- **Windows**: PowerShell 5.1+ 或 PowerShell Core 7+
- **包管理器**: pnpm 9.0.0+
- **Node.js**: Node.js 18+ (用于网站开发)

### 克隆仓库

```bash
git clone https://github.com/volcanicll/kitup.git
cd kitup
```

### 安装依赖

```bash
pnpm install
```

### 项目结构

```
kitup/
├── packages/
│   ├── cli/                    # CLI 工具（Shell 脚本）
│   │   ├── kitup.sh           # Unix/Linux/macOS 实现
│   │   ├── kitup.ps1          # Windows PowerShell 实现
│   │   ├── install.sh         # Unix 安装程序
│   │   ├── install.ps1        # Windows 安装程序
│   │   ├── test-regression.sh # 回归测试
│   │   ├── test-unit.sh       # 单元测试
│   │   └── package.json
│   │
│   └── website/               # 官方网站（Next.js）
│       ├── src/app/
│       ├── dist/
│       └── package.json
│
├── .github/workflows/          # CI/CD 配置
├── turbo.json                 # Turborepo 配置
├── pnpm-workspace.yaml        # 工作区配置
└── README.md
```

## 开发工作流

### 1. 创建功能分支

```bash
git checkout -b feature/your-feature-name
# 或
git checkout -b fix/your-bug-fix
```

分支命名规范：
- `feature/` - 新功能
- `fix/` - Bug 修复
- `docs/` - 文档更新
- `test/` - 测试相关
- `refactor/` - 代码重构

### 2. 进行开发

#### 添加新的 AI 工具支持

1. **编辑 `kitup.sh`**：
   ```bash
   # 在 TOOLS 数组中添加工具定义
   # 格式: name|command|npm_package|brew_formula|pipx_package|uv_package|github_repo|install_url
   "newtool|newtool|newtool-pkg|newtool-formula|||user/newtool-repo|https://example.com/install"
   ```

2. **编辑 `kitup.ps1`**：
   ```powershell
   # 在 TOOLS 数组中添加工具定义
   # 格式: Name, Command, NpmPackage, BrewFormula, PipxPackage, UvPackage, GitHubRepo, InstallUrl, ChocoPackage, ScoopPackage
   @("newtool", "newtool", "newtool-pkg", "newtool-formula", $null, $null, "user/newtool-repo", "https://example.com/install", $null, $null)
   ```

3. **更新文档**：
   - 在 `README.md` 中添加工具说明
   - 在 `packages/cli/README.md` 中更新支持的工具列表

#### 添加配置备份路径

在 `kitup.sh` 的 `backup_configs()` 函数中添加：
```bash
local configs=(
    # 现有配置...
    "$HOME/.config/newtool"
)
```

在 `kitup.ps1` 的 `Backup-Configs` 函数中添加：
```powershell
$configs = @(
    # 现有配置...
    "$env:USERPROFILE\.config\newtool"
)
```

### 3. 运行测试

```bash
# 运行所有测试
pnpm test

# 仅运行回归测试
cd packages/cli
./test-regression.sh

# 仅运行单元测试
cd packages/cli
./test-unit.sh
```

### 4. 代码检查

```bash
# Shell 脚本检查
shellcheck packages/cli/kitup.sh

# PowerShell 脚本检查（Windows）
Invoke-ScriptAnalyzer -Path packages/cli/kitup.ps1
```

### 5. 提交更改

```bash
git add .
git commit -m "feat: add support for NewTool AI assistant"
```

#### 提交信息规范

使用 [Conventional Commits](https://www.conventionalcommits.org/) 格式：

- `feat:` - 新功能
- `fix:` - Bug 修复
- `docs:` - 文档更新
- `test:` - 测试相关
- `refactor:` - 代码重构
- `chore:` - 构建/工具相关

示例：
```
feat: add support for Cursor CLI

- Add cursor tool definition to TOOLS array
- Update version to 0.0.12
- Add backup path for cursor config
- Add tests for cursor version detection
```

### 6. 推送和创建 PR

```bash
git push origin feature/your-feature-name
```

然后在 GitHub 上创建 Pull Request。

## 编码规范

### Shell 脚本（kitup.sh）

- 使用 4 空格缩进
- 函数命名使用 `snake_case`
- 使用双括号 `[[ ]]` 进行条件测试
- 始终引用变量：`"$var"`
- 使用 `local` 声明局部变量
- 添加有意义的注释

```bash
# Good
get_local_version() {
    local cmd="$1"
    local version_str

    if ! command_exists "$cmd"; then
        echo ""
        return
    fi

    version_str=$($cmd --version 2>/dev/null || echo "")
    parse_version "$version_str"
}
```

### PowerShell（kitup.ps1）

- 使用 4 空格缩进
- 函数命名使用 `PascalCase`
- 使用 `cmdletbinding` 和参数属性
- 添加有意义的注释

```powershell
# Good
function Get-LocalVersion {
    param(
        [Parameter(Mandatory=$true)]
        [string]$Command
    )

    if (!(Test-CommandExists $Command)) {
        return $null
    }

    $versionStr = & $Command --version 2>$null
    return Get-ParsedVersion $versionStr
}
```

## 测试指南

### 单元测试

单元测试位于 `packages/cli/test-unit.sh`，测试独立函数：

```bash
# 测试版本解析函数
result=$(parse_version "1.2.3")
assert_equals "1.2.3" "$result" "parse_version handles standard version"

# 测试版本比较函数
version_is_newer "1.2.4" "1.2.3" && pass "version_is_newer works"
```

### 回归测试

回归测试位于 `packages/cli/test-regression.sh`，测试完整用户流程：

```bash
# 创建模拟命令
make_stub "$TMP_DIR/bin/npm" '
if [ "$1" = "view" ] && [ "$2" = "package" ]; then
  echo "1.0.0"
  exit 0
fi
'

# 运行测试
PATH="$TEST_PATH" bash "$ROOT_DIR/kitup.sh" tool-name -n
assert_contains "$output" "expected output" "test description"
```

### 添加新测试

1. 在 `test-unit.sh` 中添加单元测试
2. 在 `test-regression.sh` 中添加回归测试
3. 确保所有测试通过：`pnpm test`

## 发布流程

发布由维护者通过 GitHub Actions 自动处理：

1. 更新 `CHANGELOG.md`
2. 更新 `kitup.sh` 和 `kitup.ps1` 中的 `VERSION`
3. 创建 git tag：`git tag v0.0.12`
4. 推送 tag：`git push origin v0.0.12`
5. GitHub Actions 自动构建和发布

## 获取帮助

- **Issues**: [GitHub Issues](https://github.com/volcanicll/kitup/issues)
- **Discussions**: [GitHub Discussions](https://github.com/volcanicll/kitup/discussions)

## 行为准则

- 尊重所有贡献者
- 使用友好和包容的语言
- 专注于对项目最有利的事情

## 许可证

通过贡献到 Kitup，您同意您的贡献将在与项目相同的 [MIT 许可证](LICENSE) 下发布。
