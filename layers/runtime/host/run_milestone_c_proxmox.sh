#!/usr/bin/env bash
# Milestone C on Proxmox VE — create VM, cloud-init, run guest milestone scripts.
set -euo pipefail

PROXMOX_HOST="${PROXMOX_HOST:-root@192.168.1.220}"
PROXMOX_STORAGE="${PROXMOX_STORAGE:-local-lvm}"
VMID="${VMID:-9100}"
VM_NAME="${VM_NAME:-aions-milestone-c}"
LOG_DIR="${LOG_DIR:-/mnt/d/AIONS_DEV/logs/milestone-c-proxmox}"
REPO_ROOT="${REPO_ROOT:-/mnt/e/server wiedzy}"
PRIV_KEY="${PRIV_KEY:-/mnt/d/AIONS_DEV/vm/aions-milestone-c/keys/id_ed25519}"
PUB_KEY="${PUB_KEY:-/mnt/d/AIONS_DEV/vm/aions-milestone-c/keys/id_ed25519.pub}"
GUEST_USER="${GUEST_USER:-ubuntu}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
HOST_DIR="${SCRIPT_DIR}"
PROXMOX_DIR="${SCRIPT_DIR}/proxmox"
REPO_TGZ="${REPO_TGZ:-/tmp/aions-repo.tgz}"

log() { echo "[$(date -Iseconds)][PROXMOX] $*" | tee -a "${LOG_DIR}/host.log"; }

mkdir -p "${LOG_DIR}"
[[ -f "${PUB_KEY}" ]] || { log "Brak klucza SSH: ${PUB_KEY}"; exit 1; }

PUB="$(cat "${PUB_KEY}")"
sed "s|\${SSH_PUBLIC_KEY}|${PUB}|g" "${PROXMOX_DIR}/cloud-init-user-data.yaml" > "${LOG_DIR}/user-data.yaml"
cp "${PROXMOX_DIR}/network-config.yaml" "${LOG_DIR}/network-config.yaml"

log "Tworzenie cloud-init ISO..."
if [[ "${SKIP_VM_CREATE:-0}" == "1" ]]; then
  log "SKIP_VM_CREATE=1 — pomijam lokalne cidata.iso"
elif command -v xorriso >/dev/null 2>&1; then
  xorriso -as mkisofs -output "${LOG_DIR}/cidata.iso" -volid cidata -joliet -rock \
    "${LOG_DIR}/user-data.yaml" "${LOG_DIR}/network-config.yaml" \
    -map "${LOG_DIR}/user-data.yaml" /user-data \
    -map "${LOG_DIR}/network-config.yaml" /network-config 2>/dev/null || true
else
  log "xorriso niedostępny — użyj ręcznie cloud-init drive w Proxmox GUI"
fi

SSH_OPTS=(-o StrictHostKeyChecking=no -o BatchMode=yes)
EFFECTIVE_KEY="/tmp/aions_mc_key"
if [[ -f "${PRIV_KEY}" ]]; then
  cp "${PRIV_KEY}" "${EFFECTIVE_KEY}" && chmod 600 "${EFFECTIVE_KEY}"
  SSH_OPTS+=(-i "${EFFECTIVE_KEY}")
fi

setup_proxmox_key() {
  scp "${SSH_OPTS[@]}" "${EFFECTIVE_KEY}" "${PROXMOX_HOST}:/tmp/aions_mc_key"
  ssh "${SSH_OPTS[@]}" "${PROXMOX_HOST}" "chmod 600 /tmp/aions_mc_key"
}

guest_ssh() {
  local ip="$1"; shift
  local cmd="$*"
  ssh "${SSH_OPTS[@]}" "${PROXMOX_HOST}" \
    "ssh -o StrictHostKeyChecking=no -o ConnectTimeout=20 -i /tmp/aions_mc_key ${GUEST_USER}@${ip} $(printf '%q' "${cmd}")"
}

guest_scp() {
  local ip="$1" remote="$2"; shift 2
  local f base staging="/tmp/aions_mc_staging"
  ssh "${SSH_OPTS[@]}" "${PROXMOX_HOST}" "rm -rf ${staging} && mkdir -p ${staging}"
  for f in "$@"; do
    base="$(basename "${f}")"
    scp "${SSH_OPTS[@]}" "${f}" "${PROXMOX_HOST}:${staging}/${base}"
    ssh "${SSH_OPTS[@]}" "${PROXMOX_HOST}" \
      "scp -o StrictHostKeyChecking=no -i /tmp/aions_mc_key ${staging}/${base} ${GUEST_USER}@${ip}:${remote}"
  done
}

test_guest_ssh() {
  local ip="$1"
  guest_ssh "${ip}" "echo ok" >/dev/null 2>&1
}

get_vm_mac() {
  ssh "${SSH_OPTS[@]}" "${PROXMOX_HOST}" "qm config ${VMID}" 2>/dev/null \
    | sed -n 's/^net0:.*virtio=\([^,]*\),.*/\1/p' | head -1 | tr '[:upper:]' '[:lower:]'
}

discover_guest_ip() {
  local mac="$1" ip=""
  # a) qemu-guest-agent (if running)
  ip="$(ssh "${SSH_OPTS[@]}" "${PROXMOX_HOST}" \
    "qm guest cmd ${VMID} network-get-interfaces 2>/dev/null" \
    | grep -oE '([0-9]{1,3}\.){3}[0-9]{1,3}' | grep -v '^127\.' | head -1 || true)"
  [[ -n "${ip}" ]] && { echo "${ip}"; return 0; }
  # b) ip neigh on Proxmox bridge for VM MAC
  if [[ -n "${mac}" ]]; then
    ip="$(ssh "${SSH_OPTS[@]}" "${PROXMOX_HOST}" \
      "ip neigh show dev vmbr0 2>/dev/null" \
      | grep -i "${mac}" | grep -oE '^([0-9]{1,3}\.){3}[0-9]{1,3}' | head -1 || true)"
    [[ -n "${ip}" ]] && { echo "${ip}"; return 0; }
    # c) arp / full neigh fallback
    ip="$(ssh "${SSH_OPTS[@]}" "${PROXMOX_HOST}" \
      "(arp -n 2>/dev/null; ip neigh show 2>/dev/null)" \
      | grep -i "${mac}" | grep -oE '([0-9]{1,3}\.){3}[0-9]{1,3}' | head -1 || true)"
  fi
  echo "${ip}"
}

if [[ "${SKIP_VM_CREATE:-0}" == "1" ]]; then
  log "SKIP_VM_CREATE=1 — pomijam tworzenie VM ${VMID}"
else
log "Zdalne tworzenie VM na ${PROXMOX_HOST}..."
ssh "${SSH_OPTS[@]}" "${PROXMOX_HOST}" bash -s <<REMOTE
set -e
PUBKEY='$(echo "${PUB}" | sed "s/'/'\\\\''/g")'
VMID=${VMID}
STORAGE=${PROXMOX_STORAGE}
NAME=${VM_NAME}
CLOUD_IMG="/var/lib/vz/template/iso/jammy-server-cloudimg-amd64.img"
if [[ ! -f "\$CLOUD_IMG" ]]; then
  wget -q -O "\$CLOUD_IMG" "https://cloud-images.ubuntu.com/releases/22.04/release/ubuntu-22.04-server-cloudimg-amd64.img" || true
fi
qm destroy "\$VMID" 2>/dev/null || true
qm create "\$VMID" --name "\$NAME" --memory 4096 --cores 2 --net0 virtio,bridge=vmbr0
qm importdisk "\$VMID" "\$CLOUD_IMG" "\$STORAGE"
qm set "\$VMID" --scsihw virtio-scsi-pci --scsi0 "\${STORAGE}:vm-\${VMID}-disk-0"
qm resize "\$VMID" scsi0 40G
qm set "\$VMID" --ide2 "\${STORAGE}:cloudinit"
qm set "\$VMID" --ipconfig0 ip=192.168.1.150/24,gw=192.168.1.254
echo "\$PUBKEY" > "/tmp/vm-\${VMID}-sshkey.pub"
qm set "\$VMID" --sshkeys "/tmp/vm-\${VMID}-sshkey.pub"
qm set "\$VMID" --boot order=scsi0
qm set "\$VMID" --serial0 socket --vga serial0
qm set "\$VMID" --agent enabled=1
qm start "\$VMID"
REMOTE
fi

setup_proxmox_key
log "Klucz SSH skopiowany na Proxmox (hop do guesta)"

log "Czekam na SSH..."
VM_MAC="$(get_vm_mac)"
log "VM MAC=${VM_MAC:-unknown}"
IP=""
for i in $(seq 1 60); do
  IP="$(discover_guest_ip "${VM_MAC}")"
  log "IP wait ${i}/60: discovered=${IP:-none}"
  if [[ -n "${IP}" ]]; then
    if test_guest_ssh "${IP}"; then
      log "SSH OK na ${IP}"
      break
    fi
    log "IP ${IP} znaleziony ale SSH jeszcze nie — czekam"
    IP=""
  fi
  sleep 10
done
[[ -n "${IP}" ]] || { log "Timeout SSH po 60 próbach"; exit 1; }
log "Guest IP=${IP}"

fix_guest_network() {
  local ip="$1"
  log "Naprawa routingu guest (NAT via Proxmox)..."
  ssh "${SSH_OPTS[@]}" "${PROXMOX_HOST}" bash -s <<'REMOTE'
sysctl -w net.ipv4.ip_forward=1
iptables -t nat -C POSTROUTING -s 192.168.1.150/32 -o vmbr0 -j MASQUERADE 2>/dev/null || \
  iptables -t nat -A POSTROUTING -s 192.168.1.150/32 -o vmbr0 -j MASQUERADE
iptables -C FORWARD -s 192.168.1.150 -j ACCEPT 2>/dev/null || iptables -A FORWARD -s 192.168.1.150 -j ACCEPT
iptables -C FORWARD -d 192.168.1.150 -j ACCEPT 2>/dev/null || iptables -A FORWARD -d 192.168.1.150 -j ACCEPT
REMOTE
  guest_ssh "${ip}" "sudo ip route replace default via 192.168.1.220 dev eth0; \
    sudo rm -f /etc/resolv.conf; echo nameserver 8.8.8.8 | sudo tee /etc/resolv.conf >/dev/null; \
    ping -c1 -W3 8.8.8.8 >/dev/null && echo net_ok || echo net_fail"
}
fix_guest_network "${IP}"

log "Kopiowanie repo i skryptow na guest (${REPO_TGZ})..."
if [[ ! -f "${REPO_TGZ}" ]]; then
  log "Pakowanie repo.tgz..."
  tar -czf "${REPO_TGZ}" -C "${REPO_ROOT}" . \
    --exclude='./venv' --exclude='./.git' --exclude='./data/chroma' --exclude='./scan_results'
fi
guest_scp "${IP}" "/tmp/" "${REPO_TGZ}"
guest_scp "${IP}" "/tmp/" \
  "${HOST_DIR}/guest_milestone_c_run.sh" \
  "${HOST_DIR}/scripts/guest_pre_install.sh"
guest_ssh "${IP}" "chmod +x /tmp/guest_pre_install.sh /tmp/guest_milestone_c_run.sh && bash /tmp/guest_pre_install.sh /tmp/guest_milestone_c_run.sh /tmp/aions-repo.tgz /tmp/aions-repo"
EC1=$?

guest_ssh "${IP}" "sudo reboot" || true
sleep 45
for i in $(seq 1 60); do
  test_guest_ssh "${IP}" && break
  sleep 10
done

guest_scp "${IP}" "/tmp/" \
  "${HOST_DIR}/guest_milestone_c_post_reboot.sh" \
  "${HOST_DIR}/scripts/guest_post_install.sh"
guest_ssh "${IP}" "chmod +x /tmp/guest_post_install.sh /tmp/guest_milestone_c_post_reboot.sh && bash /tmp/guest_post_install.sh /tmp/guest_milestone_c_post_reboot.sh"
EC2=$?

HEALTH="FAIL"
[[ "${EC1}" -eq 0 && "${EC2}" -eq 0 ]] && HEALTH="PASS"
log "WYNIK IP=${IP} pre=${EC1} post=${EC2} strict-health=${HEALTH}"
printf '{"vm_ip":"%s","pre_reboot_exit":%s,"post_reboot_exit":%s,"strict_health":"%s","platform":"proxmox"}\n' \
  "${IP}" "${EC1}" "${EC2}" "${HEALTH}" > "${LOG_DIR}/result.json"
[[ "${HEALTH}" == "PASS" ]] || exit 1
