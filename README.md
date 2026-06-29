# 🌐 校园网自动登录

校园网自动登录工具，包含两个实现：

- **Windows Selenium 版**：适合电脑开机后自动登录校园网认证页面。
- **Router Dr.COM 版**：适合 SSH 解锁后的路由器直接承担校园网登录，不依赖电脑开机。

> ⚠️ 本仓库只提交模板与通用脚本。真实账号、密码、HAR 抓包、日志、学校内网地址请勿提交。

## Windows Selenium 版

### 1. 安装依赖

需要 Python 3.8+ 和 Microsoft Edge 浏览器。

```bash
pip install -r requirements.txt
```

### 2. 创建配置文件

```bash
cp config.ini.example config.ini
```

编辑 `config.ini`：

```ini
[login]
url = http://PORTAL_HOST/a79.htm?wlanacname=Huawei
username = 你的学号
password = 你的密码
isp = @cmcc
```

`config.ini` 包含账号密码，已被 `.gitignore` 排除，不要提交。

### 3. 运行

```bash
python auto_login.py
```

或双击 `login.bat`。

### 4. Windows 开机自启动

可把 `login.bat` 或静默启动脚本放入：

```text
shell:startup
```

也可以使用任务计划程序，在用户登录时运行。

## Router Dr.COM 版

见 [`router/README.md`](router/README.md)。

核心思路：路由器每分钟检测是否联网；如果离线，使用 Dr.COM / EPortal 的 JSONP 登录接口提交认证；如果已联网，则跳过。

日志默认保存在：

```sh
/data/campus-login/campus-login.log
```

## 配置说明

### Windows `config.ini`

| 配置项 | 说明 | 默认值 |
| --- | --- | --- |
| `url` | 校园网认证页面地址 | — |
| `username` | 学号 | — |
| `password` | 密码 | — |
| `isp` | 运营商后缀，例如 `@cmcc` | `@cmcc` |
| `headless` | 无头模式 | `true` |
| `timeout` | 页面元素等待超时秒数 | `10` |
| `retry_count` | 失败重试次数 | `3` |
| `retry_delay` | 重试间隔秒数 | `5` |
| `startup_delay` | 开机延迟秒数 | `10` |

## 文件说明

```text
.
├── auto_login.py             # Windows Selenium 主脚本
├── config.ini.example        # Windows 配置模板
├── login.bat                 # Windows 启动脚本
├── requirements.txt          # Python 依赖
├── router/
│   ├── README.md
│   ├── drcom-router-login.sh
│   └── router-config.example
└── README.md
```

## 安全提醒

- 不要提交 `config.ini`、`/data/campus-login/config`、HAR 抓包或日志。
- HAR / Copy as cURL 里通常包含账号密码，分享前必须脱敏。
- 路由器脚本日志不会记录密码，但会记录 portal 返回摘要，公开日志前仍建议检查。

## License

[MIT](LICENSE)
