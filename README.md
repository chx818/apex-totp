# VivoKey Apex-TOTP (RAM-Optimized for NXP JCOP 4/5)

[English](#english) | [中文说明](#中文说明)

---

<a name="english"></a>
## English

A JavaCard implementation of the OATH (HOTP / TOTP) applet, compatible with the YubiKey NEO OATH protocol and the **Yubico Authenticator** applications (desktop, Android, iOS over NFC and contact CCID).

This fork features a **critical RAM optimization** designed for modern secure elements (such as NXP JCOP 4.x / 5.x / J3R452) where Clear-On-Reset (COR) RAM is scarce and shared among all installed applets.

### ⚡ The RAM Optimization

#### Problem in Upstream
On NXP JCOP 4 / JCOP 5 platforms (such as the J3R452, CC EAL6+ secure element):
- **Clear-On-Reset (COR) RAM** is limited (typically ~200 bytes total) and globally shared by the OS and all installed applets.
- **Clear-On-Deselect (COD) RAM** is much more abundant (~2.5 KB to 8 KB+ free).

Upstream `apex-totp` allocates two 28-byte transient byte arrays (`tar1` and `tar2`, total **56 bytes**) with `JCSystem.CLEAR_ON_RESET`. These arrays are merely ephemeral scratch buffers used to burn CPU cycles when simulating an authentication delay after a failed password verification.

When a card is loaded with multiple cryptographic applets (e.g., SmartPGP, FIDO2, PIV, Satochip, SeedKeeper):
- Only ~40–50 bytes of COR RAM may remain available.
- Attempting to install upstream `apex-totp` causes the card to return `0x6F00` (`SW_UNKNOWN`) due to memory allocation failure (`NO_TRANSIENT_SPACE`).

#### Solution
In `com.vivokey.otp.YkneoOath`:
```java
/* Optimize JCOP 4/5 RAM: allocate tar1/tar2 in CLEAR_ON_DESELECT instead of CLEAR_ON_RESET
 * to save 56 bytes of scarce COR RAM. tar1/tar2 are only ephemeral scratch buffers for
 * burning CPU cycles on failed password authentication. */
tar1 = JCSystem.makeTransientByteArray((short) 28, JCSystem.CLEAR_ON_DESELECT);
tar2 = JCSystem.makeTransientByteArray((short) 28, JCSystem.CLEAR_ON_DESELECT);
```

By switching to `CLEAR_ON_DESELECT`:
- **56 bytes** of scarce COR RAM are freed and moved to COD RAM.
- Static COR RAM consumption of the applet drops to **0 bytes** (apart from the JCOP kernel's standard 6-byte applet registration).
- The applet can now be installed and run concurrently alongside full-fledged cryptographic applets on memory-constrained secure elements without any side effects or loss of functionality.

### 📋 Applet Information

- **Package AID**: `A00000052721010141504558`
- **Applet AID**: `A0000005272101014150455801`
- **Supported Standards**:
  - RFC 4226 (HOTP)
  - RFC 6238 (TOTP - SHA-1, SHA-256)
  - YubiKey NEO OATH Applet Protocol

### 🛠️ Building

#### Requirements
- JDK 11 (or JDK 8/17 compatible with JavaCard development)
- Apache Ant
- JavaCard SDK 3.0.4+ (set via `JC_HOME` environment variable)

#### Quick Build (Windows)
Run the included build script:
```cmd
build.bat
```

#### Manual Build with Ant
```bash
export JC_HOME=/path/to/jc304_kit
ant dist
```
The compiled CAP file will be generated at `target/vivokey-otp.cap`.

### 📲 Installation

Install using [GlobalPlatformPro](https://github.com/martinpaljak/GlobalPlatformPro):

```bash
gp --install target/vivokey-otp.cap
```

To list installed applets and verify:
```bash
gp --list
```
Look for AID `A0000005272101014150455801`.

### 🧪 Tested Hardware & Configuration

This build has been verified on physical hardware:
- **Card**: NXP JCOP 4.5 J3R452 (Dual Interface, 452KB Flash, CC EAL6+)
- **Concurrent Co-existing Applets (All 7 active & SELECTABLE)**:
  1. SmartPGP (Curve25519 hardware-accelerated Ed25519/X25519 + RSA + NIST P-256)
  2. FIDO2 / WebAuthn
  3. PivApplet (NIST SP 800-73-4 PIV)
  4. SatoChip (BIP32/BIP39 Hardware Wallet)
  5. SeedKeeper (Encrypted Secret Backup)
  6. **VivoKey Apex-TOTP (this applet)**
  7. NDEF Type 4 Tag

---

<a name="中文说明"></a>
## 中文说明

这是一个 JavaCard 上的 OATH（HOTP / TOTP）Applet 实现，兼容 YubiKey NEO OATH 协议及全平台 **Yubico Authenticator** 客户端（支持桌面端、Android、iOS，经由 NFC 或接触式 CCID 连接）。

本分支针对以 **NXP JCOP 4.x / 5.x / J3R452** 为代表的现代高安全等级安全芯片（Secure Element）进行了关键的 **RAM 内存分配优化**，解决了多应用共存时 COR RAM 不足导致安装失败的问题。

### ⚡ RAM 优化原理

#### 上游原版存在的问题
在 NXP JCOP 4 / JCOP 5 架构芯片（如 J3R452，CC EAL6+）上：
- **Clear-On-Reset (COR) RAM** 空间极度稀缺（整卡通常仅约 200 字节），且由 JCOP 内核及所有已安装 Applet 全局共享。
- **Clear-On-Deselect (COD) RAM** 空间相对充裕（通常剩余约 2.5 KB 至 8 KB 以上）。

上游 `apex-totp` 在初始化时分配了两个 28 字节的临时数组（`tar1` 和 `tar2`，共计 **56 字节**），且指定了 `JCSystem.CLEAR_ON_RESET`。这两个数组的作用仅仅是在密码校验失败时执行哈希循环以消耗 CPU 时钟、模拟延迟。

当卡内已经安装了多套重型密码学 Applet（例如 SmartPGP、FIDO2、PIV、Satochip、SeedKeeper）时：
- 卡内剩余的 COR RAM 通常仅剩 40～50 字节；
- 此时安装原版 `apex-totp` 会由于瞬态内存不足（`NO_TRANSIENT_SPACE`）抛出 `0x6F00` 错误并导致安装失败。

#### 解决方案
在 `com.vivokey.otp.YkneoOath` 中：
```java
/* 优化 JCOP 4/5 RAM：将 tar1/tar2 改为 CLEAR_ON_DESELECT 分配，
 * 避免占用宝贵的全局 COR RAM。tar1/tar2 仅用于密码验证失败时的延时擦除计算。 */
tar1 = JCSystem.makeTransientByteArray((short) 28, JCSystem.CLEAR_ON_DESELECT);
tar2 = JCSystem.makeTransientByteArray((short) 28, JCSystem.CLEAR_ON_DESELECT);
```

改为 `CLEAR_ON_DESELECT` 后：
- 成功释放了 **56 字节** 的宝贵 COR RAM，将其转入充裕的 COD RAM；
- 该 Applet 的静态 COR RAM 占用降为 **0 字节**（仅需 JCOP 内核注册实例所需的 6 字节固定开销）；
- 彻底解决了内存碰撞，使 TOTP/HOTP 可以与全套智能卡应用完美共存于同一张卡片中，且不影响任何安全性与功能。

### 📋 Applet 标识信息

- **Package AID**: `A00000052721010141504558`
- **Applet AID**: `A0000005272101014150455801`
- **支持标准**:
  - RFC 4226 (HOTP)
  - RFC 6238 (TOTP - SHA-1, SHA-256)
  - YubiKey NEO OATH Applet 协议

### 🛠️ 编译构建

#### 环境要求
- JDK 11（或适配 JavaCard 开发的 JDK 8/17）
- Apache Ant
- JavaCard SDK 3.0.4+（通过环境变量 `JC_HOME` 指定）

#### 快速构建 (Windows)
双击运行或在命令行执行：
```cmd
build.bat
```

#### 手动使用 Ant 构建
```bash
export JC_HOME=/path/to/jc304_kit
ant dist
```
构建生成的 CAP 文件位于 `target/vivokey-otp.cap`。

### 📲 安装部署

使用 [GlobalPlatformPro](https://github.com/martinpaljak/GlobalPlatformPro) 安装到卡片：

```bash
gp --install target/vivokey-otp.cap
```

查看已安装应用验证状态：
```bash
gp --list
```
确认列表中存在 AID `A0000005272101014150455801` 且状态为 `SELECTABLE`。

### 🧪 物理真卡验证环境

本版本已在真实物理卡片上全功能实测通过：
- **卡片型号**: NXP JCOP 4.5 J3R452 (双界面 / 452KB Flash / CC EAL6+)
- **同时共存并激活的 7 款应用（全部处于 SELECTABLE 可用状态）**:
  1. SmartPGP（Curve25519 硬件加速 Ed25519/X25519 + RSA + NIST P-256）
  2. FIDO2 / WebAuthn
  3. PivApplet（NIST SP 800-73-4 PIV 身份卡）
  4. SatoChip（BIP32/BIP39 硬件钱包）
  5. SeedKeeper（加密助记词备份）
  6. **VivoKey Apex-TOTP（本应用）**
  7. NDEF Type 4 标签

---

## 📄 License

GPL-3.0-only. See `COPYING` for details.
