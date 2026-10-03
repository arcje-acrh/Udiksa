#!/usr/bin/env bash
# title: Snapshot now
# desc: Take a manual system snapshot (snapper) -- your undo button before big changes
# terminal: yes
if ! command -v snapper >/dev/null || ! sudo snapper -c root list >/dev/null 2>&1; then
    echo "Snapshots are not set up here (they need a btrfs system). Set them up with:"
    echo "  sudo ~/Udiksa/system/setup-snapshots.sh"; exit 0
fi
read -rp "Short note for this snapshot (Enter = 'manual'): " note
sudo snapper -c root create --description "${note:-manual}" --cleanup-algorithm number
echo; sudo snapper -c root list | tail -5
