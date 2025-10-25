#!/usr/bin/env bash
set -euo pipefail

# Utilisation: SSH_HOST=hôte SSH_USER=utilisateur SSH_PASSWORD=motdepasse BACKUP=/opt/brokerx_backup_YYYYmmddHHMMSS.tgz ./scripts/rollback_vm.sh
# Ou avec clé: SSH_KEY=~/.ssh/id_rsa

REMOTE_DIR=${REMOTE_DIR:-/opt/brokerx}

if [[ -z "${SSH_HOST:-}" || -z "${SSH_USER:-}" || -z "${BACKUP:-}" ]]; then
        echo "Définir SSH_HOST, SSH_USER et BACKUP (chemin du tar de sauvegarde sur le serveur)" >&2
    exit 1
fi

if [[ -n "${SSH_PASSWORD:-}" ]]; then
    SSHCMD=(sshpass -p "$SSH_PASSWORD" ssh -o StrictHostKeyChecking=no)
elif [[ -n "${SSH_KEY:-}" ]]; then
    SSHCMD=(ssh -i "$SSH_KEY" -o StrictHostKeyChecking=no)
else
        echo "Fournir la variable d'env SSH_PASSWORD ou SSH_KEY" >&2
    exit 1
fi

"${SSHCMD[@]}" "$SSH_USER@$SSH_HOST" bash -lc "\
    set -e; \
    test -f $BACKUP || { echo 'Backup not found'; exit 1; }; \
    sudo systemctl stop docker || true; sudo systemctl start docker || true; \
    docker ps >/dev/null 2>&1 || true; \
    mv $REMOTE_DIR ${REMOTE_DIR}.failed.$(date +%s) || true; \
    mkdir -p $REMOTE_DIR && tar -xzf $BACKUP -C $(dirname $REMOTE_DIR) && echo Restored; \
    cd $REMOTE_DIR; docker compose up -d --build; docker compose ps; \
    curl -fsS http://localhost:3000/health && echo ' Health OK' || (echo ' Health failed' && exit 1)
"
