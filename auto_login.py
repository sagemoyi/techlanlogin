"""
校园网自动登录脚本 v2.1

改进:
- Selenium 4 自动管理浏览器驱动 + 离线缓存回退
- 外部配置文件管理账号信息
- 日志记录（控制台 + 文件）
- 联网预检 & 自动重试
- 登录结果检测
"""

import sys
import time
import logging
from pathlib import Path
from configparser import ConfigParser
from urllib.request import urlopen
from urllib.error import URLError

# ── 路径 ──────────────────────────────────────────────

SCRIPT_DIR = Path(__file__).parent
CONFIG_PATH = SCRIPT_DIR / "config.ini"
LOG_PATH = SCRIPT_DIR / "login.log"

ISP_NAMES = {
    "@cmcc": "中国移动",
    "@telecom": "中国电信",
    "@unicom": "中国联通",
}


# ── 日志 ──────────────────────────────────────────────

def setup_logging() -> logging.Logger:
    """配置日志：同时输出到控制台和文件。"""
    logger = logging.getLogger("autologin")
    if logger.handlers:          # 防止重复添加
        return logger
    logger.setLevel(logging.INFO)

    fmt = logging.Formatter(
        "[%(asctime)s] %(levelname)s  %(message)s",
        datefmt="%Y-%m-%d %H:%M:%S",
    )

    fh = logging.FileHandler(LOG_PATH, encoding="utf-8")
    fh.setFormatter(fmt)
    logger.addHandler(fh)

    ch = logging.StreamHandler()
    ch.setFormatter(fmt)
    logger.addHandler(ch)

    return logger


# ── 配置 ──────────────────────────────────────────────

def load_config() -> ConfigParser:
    """读取 config.ini，不存在则终止并提示。"""
    if not CONFIG_PATH.exists():
        print(f"❌ 找不到配置文件: {CONFIG_PATH}")
        print("   请先创建 config.ini，参考 README.md")
        sys.exit(1)

    cfg = ConfigParser()
    cfg.read(CONFIG_PATH, encoding="utf-8")
    return cfg


# ── 联网检测 ──────────────────────────────────────────

def is_internet_available(timeout: int = 3) -> bool:
    """访问百度首页，若返回内容包含 'baidu' 则已联网。"""
    try:
        resp = urlopen("http://www.baidu.com", timeout=timeout)
        return b"baidu" in resp.read(512)
    except Exception:
        return False


# ── 离线驱动回退 ──────────────────────────────────────

def find_cached_edgedriver() -> str | None:
    """
    扫描 Selenium 缓存目录，找到已下载的 msedgedriver.exe。
    解决断网时 SeleniumManager 无法联网下载驱动的问题。
    """
    cache_base = Path.home() / ".cache" / "selenium" / "msedgedriver"
    if not cache_base.exists():
        return None

    # 查找所有缓存的 msedgedriver.exe，取最新版本
    drivers = sorted(cache_base.glob("**/msedgedriver.exe"), reverse=True)
    if drivers:
        return str(drivers[0])
    return None


# ── 主流程 ────────────────────────────────────────────

def main() -> None:
    # 延迟导入：未安装 selenium 时给出友好提示
    try:
        from selenium import webdriver
        from selenium.webdriver.common.by import By
        from selenium.webdriver.support.ui import Select, WebDriverWait
        from selenium.webdriver.support import expected_conditions as EC
    except ImportError:
        print("❌ 未安装 selenium，请执行:  pip install selenium")
        sys.exit(1)

    log = setup_logging()
    cfg = load_config()

    # ── 读取配置 ──
    url         = cfg.get("login", "url")
    username    = cfg.get("login", "username")
    password    = cfg.get("login", "password")
    isp         = cfg.get("login", "isp", fallback="@cmcc")
    headless    = cfg.getboolean("settings", "headless", fallback=True)
    timeout     = cfg.getint("settings", "timeout", fallback=10)
    retries     = cfg.getint("settings", "retry_count", fallback=3)
    retry_wait  = cfg.getint("settings", "retry_delay", fallback=5)
    boot_delay  = cfg.getint("settings", "startup_delay", fallback=0)

    log.info("=" * 45)
    log.info("校园网自动登录 启动")

    # ── 开机延迟（等网卡就绪）──
    if boot_delay > 0:
        log.info(f"等待 {boot_delay} 秒（等待网络适配器就绪）...")
        time.sleep(boot_delay)

    # ── 联网预检 ──
    if is_internet_available():
        log.info("✅ 已联网，无需登录，退出")
        log.info("=" * 45)
        return

    log.info(f"目标地址: {url}")
    log.info(f"运行模式: {'无头(后台)' if headless else '有界面'}")

    # ── 浏览器选项 ──
    opts = webdriver.EdgeOptions()
    opts.add_argument("--ignore-certificate-errors")
    opts.add_argument("--disable-gpu")
    opts.add_argument("--no-sandbox")
    opts.add_argument("--log-level=3")           # 抑制浏览器自身日志
    if headless:
        opts.add_argument("--headless=new")

    # ── 重试循环 ──
    driver = None
    for attempt in range(1, retries + 1):
        try:
            log.info(f"第 {attempt}/{retries} 次尝试")

            # 先尝试自动管理驱动；失败则用缓存的驱动（解决断网时无法下载的问题）
            try:
                driver = webdriver.Edge(options=opts)
            except Exception:
                cached = find_cached_edgedriver()
                if cached:
                    log.info(f"自动驱动获取失败，使用缓存驱动: {cached}")
                    from selenium.webdriver.edge.service import Service
                    driver = webdriver.Edge(service=Service(cached), options=opts)
                else:
                    raise RuntimeError(
                        "无法获取 Edge 驱动，且本地无缓存。"
                        "请先在有网环境下运行一次脚本以缓存驱动。"
                    )

            wait = WebDriverWait(driver, timeout)

            driver.get(url)
            log.info("认证页面已打开")

            # 账号
            el = wait.until(EC.presence_of_element_located(
                (By.XPATH, "//input[contains(@placeholder,'账号')]")
            ))
            el.clear()
            el.send_keys(username)
            log.info("已输入账号")

            # 密码
            el = wait.until(EC.presence_of_element_located(
                (By.XPATH, "//input[contains(@placeholder,'密码')]")
            ))
            el.clear()
            el.send_keys(password)
            log.info("已输入密码")

            # 运营商
            sel_el = wait.until(EC.presence_of_element_located(
                (By.NAME, "ISP_select")
            ))
            Select(sel_el).select_by_value(isp)
            log.info(f"已选择运营商: {ISP_NAMES.get(isp, isp)}")

            # 登录按钮
            btn = wait.until(EC.element_to_be_clickable(
                (By.XPATH, "//input[@value='登录']")
            ))
            btn.click()
            log.info("已点击登录")

            # 等待页面响应并检测结果
            time.sleep(3)
            page = driver.page_source
            page_lower = page.lower()

            if "成功" in page or "success" in page_lower:
                log.info("✅ 登录成功!")
            elif "已经在线" in page or "already" in page_lower:
                log.info("✅ 已在线，无需重复登录")
            else:
                log.warning("⚠️ 未检测到明确的成功提示，请检查网络")

            break  # 成功即退出重试循环

        except Exception as e:
            log.error(f"第 {attempt} 次失败: {e}")
            if attempt < retries:
                log.info(f"{retry_wait} 秒后重试...")
                time.sleep(retry_wait)
            else:
                log.error("❌ 全部重试失败，请查看 login.log 排查")

        finally:
            if driver:
                driver.quit()
                driver = None

    log.info("校园网自动登录 结束")
    log.info("=" * 45)


if __name__ == "__main__":
    main()