# VivoKey Apex-TOTP (RAM-Optimized for NXP JCOP 4/5)

A JavaCard implementation of the OATH (HOTP / TOTP) applet, compatible with the YubiKey NEO OATH protocol and the **Yubico Authenticator** applications (desktop, Android, iOS over NFC and contact CCID).

This fork features a **critical RAM optimization** designed for modern secure elements (such as NXP JCOP 4.x / 5.x / J3R452) where Clear-On-Reset (COR) RAM is scarce and shared among all installed applets.

---

## ⚡ The RAM Optimization

### Problem in Upstream
On NXP JCOP 4 / JCOP 5 platforms (such as the J3R452, CC EAL6+ secure element):
- **Clear-On-Reset (COR) RAM** is limited (typically ~200 bytes total) and globally shared by the OS and all installed applets.
- **Clear-On-Deselect (COD) RAM** is much more abundant (~2.5 KB to 8 KB+ free).

Upstream `apex-totp` allocates two 28-byte transient byte arrays (`tar1` and `tar2`, total **56 bytes**) with `JCSystem.CLEAR_ON_RESET`. These arrays are merely ephemeral scratch buffers used to burn CPU cycles when simulating an authentication delay after a failed password verification.

When a card is loaded with multiple cryptographic applets (e.g., SmartPGP, FIDO2, PIV, Satochip, SeedKeeper):
- Only ~40–50 bytes of COR RAM may remain available.
- Attempting to install upstream `apex-totp` causes the card to return `0x6F00` (`SW_UNKNOWN`) due to memory allocation failure (`NO_TRANSIENT_SPACE`).

### Solution
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

---

## 📋 Applet Information

- **Package AID**: `A00000052721010141504558`
- **Applet AID**: `A0000005272101014150455801`
- **Supported Standards**:
  - RFC 4226 (HOTP)
  - RFC 6238 (TOTP - SHA-1, SHA-256)
  - YubiKey NEO OATH Applet Protocol

---

## 🛠️ Building

### Requirements
- JDK 11 (or JDK 8/17 compatible with JavaCard development)
- Apache Ant
- JavaCard SDK 3.0.4+ (set via `JC_HOME` environment variable)

### Quick Build (Windows)
Run the included build script:
```cmd
build.bat
```

### Manual Build with Ant
```bash
export JC_HOME=/path/to/jc304_kit
ant dist
```
The compiled CAP file will be generated at `target/vivokey-otp.cap`.

---

## 📲 Installation

Install using [GlobalPlatformPro](https://github.com/martinpaljak/GlobalPlatformPro):

```bash
gp --install target/vivokey-otp.cap
```

To list installed applets and verify:
```bash
gp --list
```
Look for AID `A0000005272101014150455801`.

---

## 🧪 Tested Configuration

This build has been verified on physical hardware:
- **Card**: NXP JCOP 4.5 J3R452 (Dual Interface, 452KB Flash, CC EAL6+)
- **Concurrent Co-existing Applets**:
  1. SmartPGP (Curve25519 hardware-accelerated Ed25519/X25519 + RSA + NIST P-256)
  2. FIDO2 / WebAuthn
  3. PivApplet (NIST SP 800-73-4 PIV)
  4. SatoChip (BIP32/BIP39 Hardware Wallet)
  5. SeedKeeper (Encrypted Secret Backup)
  6. **VivoKey Apex-TOTP (this applet)**
  7. NDEF Type 4 Tag

---

## 📄 License

GPL-3.0-only. See `COPYING` for details.
