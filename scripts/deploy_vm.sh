#!/usr/bin/env bash
set -euo pipefail

# Utilisation: SSH_HOST=hôte SSH_USER=utilisateur SSH_PASSWORD=motdepasse ./scripts/deploy_vm.sh
# Ou avec clé: SSH_HOST=hôte SSH_USER=utilisateur SSH_KEY=~/.ssh/id_rsa ./scripts/deploy_vm.sh

REMOTE_DIR=${REMOTE_DIR:-/opt/brokerx}

if [[ -z "${SSH_HOST:-}" || -z "${SSH_USER:-}" ]]; then
        echo "Définir SSH_HOST et SSH_USER (et SSH_PASSWORD ou SSH_KEY)" >&2
    exit 1
fi

if [[ -n "${SSH_PASSWORD:-}" ]]; then
    SCPCMD=(sshpass -p "$SSH_PASSWORD" scp -o StrictHostKeyChecking=no -r)
    SSHCMD=(sshpass -p "$SSH_PASSWORD" ssh -o StrictHostKeyChecking=no)
elif [[ -n "${SSH_KEY:-}" ]]; then
    SCPCMD=(scp -i "$SSH_KEY" -o StrictHostKeyChecking=no -r)
    SSHCMD=(ssh -i "$SSH_KEY" -o StrictHostKeyChecking=no)
else
        echo "Fournir la variable d'env SSH_PASSWORD ou SSH_KEY" >&2
    exit 1
fi

"${SSHCMD[@]}" "$SSH_USER@$SSH_HOST" bash -lc "\
    set -e; \
    if [ -d $REMOTE_DIR ]; then TS=$(date +%Y%m%d%H%M%S); tar -czf ${REMOTE_DIR}_backup_$TS.tgz -C $(dirname $REMOTE_DIR) $(basename $REMOTE_DIR); echo Backup: ${REMOTE_DIR}_backup_$TS.tgz; fi; \
    sudo mkdir -p $REMOTE_DIR; sudo chown -R $USER $REMOTE_DIR; \
"

# Copier le code sur le serveur
"${SCPCMD[@]}" . "$SSH_USER@$SSH_HOST:$REMOTE_DIR"

# Démarrer via docker compose
"${SSHCMD[@]}" "$SSH_USER@$SSH_HOST" bash -lc "\
    set -e; cd $REMOTE_DIR; \
    docker compose down --remove-orphans || true; \
    docker compose up -d --build; \
    docker compose ps; \
    curl -fsS http://localhost:3000/health && echo ' Health OK' || (echo ' Health failed' && exit 1)
"
