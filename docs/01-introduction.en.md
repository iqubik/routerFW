# file docs\01-introduction.en.md

<p align="center">
  <a href="01-introduction.md"><b>🇷🇺 Русский</b></a> | <b>🇺🇸 English</b>
</p>

---

# Lesson 1: Introduction to the Universal Builder

## The Problem: Is Custom Firmware Too Complex?

Have you ever wanted to have a firmware for your router that already has all your settings, favorite programs, and important files built-in? Not just a backup that can be restored later, but a full-fledged `.bin` file for flashing "from scratch," after which the router is immediately ready for work.

Many people, after opening the official OpenWrt build instructions, put the idea aside, saying "not today." Installing Linux, working in the command line, managing dependencies — all of this creates a high barrier to entry.

**The Universal Builder was created to solve exactly this problem.**

## Builder Philosophy: Simplicity on Windows and Linux

The project makes it possible to build custom OpenWrt firmware on Windows or Linux without turning the host into a full OpenWrt development machine. Windows uses a Batch host wrapper; Linux uses Bash. The heavy build work runs in containers.

*   **Why Docker or Podman?**\
    Compilers and build dependencies live inside a container instead of being installed manually on the host. This isolates most build tooling and makes the environment more predictable. Full reproducibility still depends on the SDK/source revision, repositories, packages, and external inputs.

*   **Why `.bat` scripts?**  
    For maximum simplicity. You don't need to install Python, MSYS2, or other tools on your system. You download one file, run it, and everything works "out of the box." This is a native and intuitive way for Windows users.

*   **Why is this better than following the official manual?**  
    The Builder is not a replacement, but a **smart automation** of official OpenWrt tools. It handles all the complex and routine work for you:
    *   **Speed:** Re-builds take only 1-3 minutes thanks to a powerful caching system.
    *   **Convenience:** A user-friendly menu instead of dozens of console commands.
    *   **Reliability:** selected network and build steps have bounded retries. The Vermagic hook can attempt to improve kernel-module compatibility; when the hook is absent, the builder has a narrow rollback for the supported Vermagic state. This is not general recovery from arbitrary errors or storage failures.

## Preparation

To work with the Builder, you only need two things:

1.  **A container runtime — Docker or Podman.** Install one supported runtime for your operating system.
    *   [Docker Desktop for Windows](https://docs.docker.com/desktop/install/windows-install/) uses a WSL2 backend.
    *   [Podman Desktop for Windows](https://podman-desktop.io/docs/installation/windows-install) manages a Linux environment/WSL machine.
    *   [Install Podman on Linux](https://podman.io/docs/installation). Docker Engine and Docker Compose are also available for Linux in the [official installation guide](https://docs.docker.com/engine/install/).
    *   On Windows, make sure the selected runtime and Compose provider are available from the command line. Bash under WSL can also use `docker.exe` / `podman.exe` when the native Linux command is unavailable.

> [Always up-to-date WSL directly from Microsoft](https://github.com/microsoft/WSL)

2.  **The Builder itself:** on Windows download `_unpacker.bat`; on Linux download `_unpacker.sh` from the root README or Releases. Place it in an empty folder and run it — it restores the project structure.

Ready-made builds (from the forum, keeneticported, etc.) are a "set and forget" option: the firmware is pre-built, but you cannot change the package set or embed your configs into the image. The Builder gives you full control: you build the firmware for yourself — your packages, settings, and updates when you need them.

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
# checksum:MD5=f6df2b100bfba8ca2d42579243041ca5