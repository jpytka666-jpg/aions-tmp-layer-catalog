# Proxmox VE install from ISO (AIONS host)

**Updated:** 2026-07-03  
**Current path:** Hyper-V nested VM `aions-proxmox-host` (no USB prepared for this session)

## ISO

| Field | Value |
|-------|-------|
| Path (VM attach) | `D:\AIONS_DEV\vm\proxmox-host\iso\proxmox-ve_9.2-1.iso` |
| Mirror / source | `E:\szul\DOWNLOAD\proxmox-ve_9.2-1.iso` (~1.59 GiB) |
| Verified | Present on host (2026-07-03) |

Do **not** store or flash images onto the `E:` volume that holds `szul\` — ISO is read-only source only.

## Hyper-V nested install (active)

| Setting | Value |
|---------|-------|
| VM name | `aions-proxmox-host` |
| Generation | **1** (required for Proxmox VE 9 installer ISO visibility) |
| RAM | 8 GiB |
| vCPU | 4 (`ExposeVirtualizationExtensions` on) |
| Disk | 80 GiB VHDX at `D:\AIONS_DEV\vm\proxmox-host\disks\aions-proxmox-host.vhdx` |
| VM config path | `D:\AIONS_DEV\vm\proxmox-host\aions-proxmox-host` |
| Network | External switch `AIONS-External` |
| NIC MAC | Static `00:15:5D:01:AB:20` (avoid DHCP clash with host `.171`) |
| Install IP | **Static** `192.168.1.220/24`, gateway `192.168.1.254` (do not use DHCP on `AIONS-External`) |
| DVD | **IDE** controller, ISO path above; BIOS boot order **CD first** |
| Secure Boot | N/A (Gen1) |

### Gen2 / ISO error workaround

On **Generation 2** VMs, GRUB may load but the Debian/Proxmox initramfs often fails with:

`[ERROR] no device with valid ISO found`

**Fix:** use **Generation 1** with an **IDE** DVD drive (not SCSI-only Gen2 DVD), CD-first boot via `Set-VMBios -StartupOrder`, and a clean VHD if a partial install was attempted.

If you must stay on Gen2: set firmware boot order to DVD first, detach/reattach the SCSI DVD with the same ISO, disable Secure Boot, and use a fresh VHDX.

### Console (what you should see)

1. Use your existing **Connect** session to **aions-proxmox-host** (do not spawn extra `vmconnect` windows).
2. At the **Proxmox VE** GRUB menu, press **Enter** on the default install entry.
3. The installer should find the ISO and continue (no initramfs ISO error).
4. Target disk = the 80 GiB virtual IDE disk only; set root password; management network on `AIONS-External`.
5. **Network step:** choose **static** `192.168.1.220/24`, gateway `192.168.1.254` — DHCP on `AIONS-External` can assign the same address as the Windows host (`192.168.1.171`) and abort the install.
6. If the graphical installer fails on tty2, use GRUB **Advanced options** → text-mode **Install Proxmox VE**.
7. After install, remove ISO from DVD or set boot order to HDD first before reboot.

### DHCP / IP conflict on AIONS-External

The external switch shares the LAN with the Windows host. A dynamic MAC can cause DHCP to hand the VM **the same IP as the host** (e.g. `192.168.1.171`), which aborts Proxmox install with *"Installation aborted - unable to continue"*.

**Fix:** set a unique static Hyper-V MAC (`00155D01AB20`) and use static install IP `192.168.1.220/24` during setup.

### Host commands (reference)

```powershell
Start-VM -Name aions-proxmox-host
Stop-VM -Name aions-proxmox-host -Force -TurnOff
# vmconnect.exe localhost aions-proxmox-host  # open manually if needed
```

## Optional: bare-metal USB later

USB flashing was **not** performed for this session. For physical install later:

- Use a **removable** USB stick (not `E:` / `szul` data disk).
- Write the same ISO with Rufus/Win32 Disk Imager / `dd`, boot target hardware from USB.

## Status log

- 2026-07-03: ISO path corrected to `E:\szul\DOWNLOAD\`; VM `proxmox-host` created on `D:\Hyper-V\`, ISO attached, VM started for nested Proxmox lab.
- 2026-07-03: **Gen2 → Gen1** recreate as `aions-proxmox-host` (IDE DVD + 80 GiB VHDX under `D:\AIONS_DEV\vm\proxmox-host\`) to fix `[ERROR] no device with valid ISO found` after GRUB on Hyper-V.
- 2026-07-03: DHCP on `AIONS-External` assigned VM `192.168.1.171` (host conflict) → installer aborted; NIC MAC set to `00155D01AB20`, doc: use static `192.168.1.220/24` during install.

- 2026-07-03: Hyper-V ISO visibility: on **aions-proxmox-host** (Gen1, IDE DVD, ISO at `D:\AIONS_DEV\vm\proxmox-host\iso\proxmox-ve_9.2-1.iso`, BIOS **CD** first), initramfs reports **found proxmox ve iso** on `/dev/sr0`. Legacy **proxmox-host** (Gen2) left **Off** to save RAM. Use **one** vmconnect session (duplicate sessions trigger takeover dialogs and stray keypresses). Graphical installer needs enough guest RAM (OOM killed installer GUI at 8 GiB with other VMs running); stop sibling VMs and prefer **10 GiB** before install. Do not match OCR substring `no such device` from modprobe as ISO failure—only the exact initramfs **no device with valid ISO found** line.
