# Home Assistant server install — the J4105 box

Step-by-step for putting Home Assistant OS on the Celeron J4105 mini PC (BIOS name `CE-S7`),
so it replaces the VirtualBox VM on the laptop as the test-phase Home Assistant host.

Written 2026-09-14. Plan is to run it 2026-09-15.

**What this box is and isn't.** It runs Home Assistant for Modules 1–8. It is *not* the
production server (single M.2 2242 SATA slot, 8 GB ceiling, and work could recall it) and it
does not go in the wall. The after-the-gates purchase plan in `MODULES.md` is unchanged.

---

## Before you start

You need:

- The J4105 box with its monitor, keyboard and mouse plugged in — same setup as the BIOS photos.
- An **Ethernet cable** from the router to the box. Not Wi-Fi.
- A **USB stick, 8 GB or bigger.** Everything on it gets erased in Part 2.
- The desktop (`STEVENRAY-PC`), for Parts 1, 2, 4 and 5.
- About 1½ hours, most of it waiting on downloads.

Already done — do not touch the BIOS again:

- Boot mode UEFI, Secure Boot disabled, no BIOS password, Fast Boot off.
- USB is Boot Option #1, Hard Disk is #2. The stick boots on its own; after it's pulled, the SSD does.

Why the stick: a computer can't erase the drive it's running from. Windows is on the SSD, so
something else has to run the box while the SSD is rewritten. That something is Ubuntu (a free
operating system) running straight off the stick in "Try Ubuntu" mode. Nothing gets installed on
the stick permanently and Ubuntu is gone the moment the stick comes out. Home Assistant OS is
what ends up on the SSD.

---

## Part 1 — Save a backup of the laptop's Home Assistant  *(desktop, 10 min)*

Everything from Module 0 — HACS, the iOS themes, the demo config — carries over through this
backup. Do it first, while the VM is still running.

1. On the desktop, open `http://192.168.1.212` (the laptop VM). Log in.
2. **Settings → System → Backups.**
3. If it asks you to *set up backups* first, go through it. It generates an encryption key and
   offers an **emergency kit** download. **Download it and keep it next to the backup file** —
   the restore in Part 4 asks for this key.
4. **Create backup → Full backup.** Wait until it shows as completed.
5. Click the backup → **⋮ → Download.** Save the `.tar` file to `Downloads`.
6. Leave the VM running for now.

---

## Part 2 — Make the Ubuntu stick  *(desktop, 20 min)*

1. Download Ubuntu Desktop: **https://ubuntu.com/download/desktop** → the big **LTS** download
   button (whatever version number it shows). It's a ~6 GB `.iso` file. Save to `Downloads`.
2. Download Rufus: **https://rufus.ie** → the **Portable** `.exe`. No install — just run it.
3. Plug in the USB stick. Copy anything you want off it now; it's about to be erased.
4. Run Rufus. If it asks about checking for updates online, click **No**.
   - **Device:** your stick. **Check the size** — make sure it's the stick and nothing else.
   - **Boot selection:** click **SELECT** → pick the `ubuntu-….iso` from `Downloads`.
   - Leave everything else alone (Partition scheme GPT, Target system UEFI).
   - Click **START**.
   - If a popup says *download required* → **Yes**.
   - Popup *ISOHybrid image detected* → keep **Write in ISO Image mode (Recommended)** → **OK**.
   - Popup *ALL DATA ON DEVICE WILL BE DESTROYED* → **OK**.
   - Wait for the green **READY** bar. 5–10 minutes. Click **CLOSE**.
5. Copy the install script onto the stick: open File Explorer, go to
   `C:\Users\steve\LaytonFamilyCommandCenter\tools\`, copy **`haos-install.sh`**, and paste it
   into the **top level** of the stick, next to the folders Rufus made.
6. Eject the stick (right-click the drive → Eject).

---

## Part 3 — Install Home Assistant on the box  *(at the box, 20 min)*

1. Box powered off. Plug in: **Ethernet cable**, **the stick**, monitor, keyboard, mouse.
2. Power on. It boots from the stick by itself. If a black text menu appears with
   **Try or Install Ubuntu** highlighted, press **Enter**. Wait 1–3 minutes; a slow stick is slow
   here and the screen may sit blank for a bit.
3. A **Welcome to Ubuntu** wizard appears. Click **Next** through language, accessibility and
   keyboard. If it asks about internet, the cable already handles it — **Next**. When it asks
   *What do you want to do with Ubuntu?* choose **Try Ubuntu** — **not** Install. You land on a
   desktop.
4. Open a terminal: press **Ctrl + Alt + T**. (Or click the 9-dot grid in the bottom-left corner
   and type `terminal`.)
5. Type this and press Enter:

   ```
   bash /cdrom/haos-install.sh
   ```

   `/cdrom` is where Ubuntu shows the stick it booted from. If it says *No such file*, the copy
   in Part 2 step 5 didn't land — type this instead, all on one line, capitals matter:

   ```
   curl -sL https://raw.githubusercontent.com/stevenxlayton/LaytonFamilyCommandCenter/main/tools/haos-install.sh | bash
   ```

6. The script lists the disks it sees and says **Internal disk looks like: /dev/sda 119.2G
   CF450…** Type **`sda`** and press Enter. (If it suggests a different name, type the one it
   suggests — the 119 GB CF450 is the right one. Never the USB stick.)
7. It shows the disk once more and asks for confirmation. Type **`YES`** in capitals, Enter.
8. It downloads Home Assistant (~500 MB) and writes it. A progress line ticks along. Several
   minutes. It ends with **Done.**
9. **Shut down — do not reboot.** Top-right corner of the screen → power icon → **Power Off**.
   If it says *Please remove the installation medium, then press ENTER* — pull the stick, press
   Enter. Wait until the box is fully off.
10. Stick out. Power on. The monitor shows scrolling text and then a plain text login prompt —
    that's normal, Home Assistant has no screen of its own. Leave it. Wait 5 minutes.

---

## Part 4 — First contact  *(desktop, 10 min)*

1. **Shut down the laptop VM first.** In VirtualBox: right-click the VM → Close → **ACPI
   Shutdown**. Otherwise two machines answer to `homeassistant.local`. Don't delete the VM — it's
   the fallback until the new box has proven itself.
2. On the desktop open **`http://homeassistant.local:8123`**. If nothing loads after 5+ minutes,
   look in the router's client list for a device named `homeassistant`, and use
   `http://<that IP>:8123`.
3. On the **Welcome!** screen, click the small **Restore from backup** link under the big button.
   Upload the `.tar` from Part 1. If it asks for an encryption key, it's in the emergency kit
   file. Then wait — it restarts itself, 5–10 minutes.
4. Log in with the same username and password as the laptop VM.
5. The VM was answering on port 80 (no `:8123`). If `:8123` stops responding after the restore,
   try **`http://homeassistant.local`** with no port — the restore carried that setting over.
6. Sanity check: **Settings → System → Hardware** should show the J4105 and 8 GB. HACS and the
   iOS theme should be where you left them.

---

## Part 5 — Tidy up  *(10 min)*

1. **Router:** reserve an IP for the new box. In the router's DHCP reservation page find the
   client `homeassistant` (the box's wired MAC) and reserve its address. Either move the old
   `.212` reservation off the VM's MAC onto this one, or reserve whatever it got. Write the
   address in `HA Important Info.txt`.
2. **Laptop:** leave the VM off. The laptop is now only the panel stand-in for Module 6.
3. **Stick:** to get it back to a normal empty drive, open Rufus → Device: the stick → Boot
   selection: **Non bootable** → **START**. Plain Windows Format won't restore the full size.
4. Tell Claude it's done so `SESSION-LOG.md` and `MODULES.md` get updated.

---

## If something goes wrong

| Symptom | Fix |
| --- | --- |
| Box boots straight into Windows | Stick wasn't in at power-on, or Rufus didn't finish. Redo Part 2 step 4. |
| Ubuntu hangs or never shows a desktop | Try a different USB port. The black USB 2.0 ports are often more reliable for booting than the blue 3.0 ones. |
| Script: *Could not find the image URL* | No internet. Check the Ethernet cable; the top-right of the Ubuntu screen should show a wired-network icon. |
| Script: *Found 2 non-USB disks* | Type `sda` — the one listed as 119G / CF450. |
| After install: *No bootable device* / *Reboot and select proper boot device* | The firmware is still looking for Windows. BIOS → Boot → **UEFI Hard Disk Drive BBS Priorities** → put the SSD entry (probably named *UEFI OS*) first → **F4** to save. |
| `homeassistant.local:8123` never loads | Look at the box's monitor — the text console prints its IP address. Use that. |
| Restore asks for a key you don't have | It's in the emergency kit from Part 1 step 3. If you never got one, the backup isn't encrypted — leave the field blank. |
| Something else | Stop. Photograph the screen. Nothing done so far is irreversible except the SSD wipe, and putting Windows back on it is free (retail digital license, activates itself). |
