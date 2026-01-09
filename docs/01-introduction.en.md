<p align="center">
  <a href="01-introduction.md"><b>🇷🇺 Русский</b></a> | <b>🇺🇸 English</b>
</p>

---

# Lesson 1: Introduction to the Universal Builder

## The Problem: Is Custom Firmware Too Complex?

Have you ever wanted to have a firmware for your router that already has all your settings, favorite programs, and important files built-in? Not just a backup that can be restored later, but a full-fledged `.bin` file for flashing "from scratch," after which the router is immediately ready for work.

Many people, after opening the official OpenWrt build instructions, put the idea aside, saying "not today." Installing Linux, working in the command line, managing dependencies — all of this creates a high barrier to entry.

**The Universal Builder was created to solve exactly this problem.**

## Builder Philosophy: Simplicity and Power on Windows

The core idea of the project is to enable any Windows user to build their own OpenWrt firmwares without turning their computer into a developer's workstation. This approach stands on three pillars:

*   **Why Docker?**  
    All the "heavy lifting" of the build process takes place inside an isolated Docker container. Your main Windows system stays clean. This also ensures that the build environment is always identical, meaning builds are reproducible and reliable. No more "it doesn't build on my machine" issues.

*   **Why `.bat` scripts?**  
    For maximum simplicity. You don't need to install Python, MSYS2, or other tools on your system. You download one file, run it, and everything works "out of the box." This is a native and intuitive way for Windows users.

*   **Why is this better than following the official manual?**  
    The Builder is not a replacement, but a **smart automation** of official OpenWrt tools. It handles all the complex and routine work for you:
    *   **Speed:** Re-builds take only 1-3 minutes thanks to a powerful caching system.
    *   **Convenience:** A user-friendly menu instead of dozens of console commands.
    *   **Reliability:** It automatically resolves typical beginner issues (like `vermagic`), works stably during network failures, and can "self-heal" when errors occur.

## Preparation

To work with the Builder, you only need two things:

1.  **Docker Desktop for Windows:** This is the environment where all builds will take place.
    *   [Download Docker Desktop from the official site](https://desktop.docker.com/win/main/amd64/Docker%20Desktop%20Installer.exe)
    *   *Note:* Docker Desktop uses the WSL2 subsystem. In modern versions of Windows, its installation and configuration are usually handled automatically along with Docker. In rare cases, if problems arise, solving them is beyond the scope of these instructions.
    
> [Always up-to-date WSL directly from Microsoft](https://github.com/microsoft/WSL)

> [Official Docker Desktop for Windows Documentation](https://docs.docker.com/desktop/install/windows-install/)

2.  **The Builder itself:** Download the `_unpacker.bat` file from the `README.md` at the root of this project. Place it in an empty folder and run it — it will automatically create all the necessary files and folders.

## Two Operating Modes

The Builder combines two approaches to firmware assembly:

#### 1. Image Builder (Fast Mode)

This is the default mode. It can be compared to packing a suitcase: you take ready-made "items" (pre-compiled packages) and neatly pack them together with your settings.
*   **Pros:** Extremely fast (subsequent builds ~2 minutes).
*   **Ideal for:** Adding programs and embedding configuration files.

#### 2. Source Builder (Powerful Mode)

This can be compared to tailoring clothes from scratch. The process is long, but you control every "stitch."
*   **Pros:** Full control over the firmware, including the kernel and drivers.
*   **Ideal for:** Deep modifications that are impossible to perform in the Fast Mode.

---

In the next lesson, we will move on to practice and create your first "cemented" backup.