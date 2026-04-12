#!/bin/bash
#898447, Alejaldre Martin, Hector, M, 3, B
#926915, Blanco Ramos, Nestor, M, 3, B

# Comprobación de permisos
if id -nG "$USER" | grep -qw sudo
then
    echo "Este script necesita privilegios de administracion"
    exit 1
fi

# Comprobación de parámetros
if [ "$#" -ne 3 ]
then
    echo "Número incorrecto de parámetros"
    exit 1
fi

OPCION=$1
FICHERO_USUARIOS=$2
FICHERO_MAQUINAS=$3

# Comprobar opción
if [ "$OPCION" != "-a" ] && [ "$OPCION" != "-s" ]
then
    echo "Opción invalida" >&2
    exit 1
fi

# Comprobar que los ficheros existen
if [ ! -f "$FICHERO_USUARIOS" ]
then
    echo "El fichero de usuarios no existe"
    exit 1
fi

if [ ! -f "$FICHERO_MAQUINAS" ]
then
    echo "El fichero de máquinas no existe"
    exit 1
fi

# Archivo de log
FECHA=$(date +"%Y_%m_%d")
USUARIO=$(whoami)
LOG_FILE="${FECHA}_${USUARIO}_provisioning.log"
touch "$LOG_FILE"

SSH="ssh -q -o BatchMode=yes -o ConnectTimeout=5 -i ~/.ssh/id_as_ed25519"

log() {
    echo "$1"
    echo "$1" >> "$LOG_FILE"
}

# Leer ficheros completos en arrays ANTES de los bucles
mapfile -t MAQUINAS < "$FICHERO_MAQUINAS"
mapfile -t USUARIOS < "$FICHERO_USUARIOS"

# Iterar sobre cada máquina
for MAQUINA in "${MAQUINAS[@]}"
do
    [ -z "$MAQUINA" ] && continue

    # Comprobar si la máquina es accesible
    $SSH as@"$MAQUINA" "exit" 2>/dev/null
    if [ $? -ne 0 ]
    then
        log "$MAQUINA no es accesible"
        continue
    fi

    # Iterar sobre cada usuario
    for LINEA in "${USUARIOS[@]}"
    do
        [ -z "$LINEA" ] && continue

        USR=$(echo "$LINEA" | cut -d',' -f1)
        PASS=$(echo "$LINEA" | cut -d',' -f2)
        FULLNAME=$(echo "$LINEA" | cut -d',' -f3)

        if [ "$OPCION" = "-a" ]
        then
            if [ -z "$USR" ] || [ -z "$PASS" ] || [ -z "$FULLNAME" ]
            then
                log "[$MAQUINA] Campo invalido"
                continue
            fi

            # Conexión 1: comprobar si el usuario existe
            $SSH as@"$MAQUINA" "id '$USR'" > /dev/null 2>&1
            if [ $? -eq 0 ]
            then
                log "[$MAQUINA] El usuario $USR ya existe"
                continue
            fi

            # Conexión 2: obtener siguiente UID
            UID_ACTUAL=$($SSH as@"$MAQUINA" "tail -n 1 /etc/passwd | cut -d: -f3" 2>/dev/null)
            if [ -n "$UID_ACTUAL" ] && [ "$UID_ACTUAL" -ge 1815 ] 2>/dev/null
            then
                NUEVO_UID=$((UID_ACTUAL + 1))
            else
                NUEVO_UID=1815
            fi

            # Conexión 3: crear usuario
            $SSH as@"$MAQUINA" "sudo /usr/sbin/useradd -m -k /etc/skel -u $NUEVO_UID -U -c '$FULLNAME' '$USR'" 2>/dev/null
            if [ $? -ne 0 ]
            then
                log "[$MAQUINA] Error al crear usuario $USR"
                continue
            fi

            # Conexión 4: asignar contraseña
            $SSH as@"$MAQUINA" "echo '$USR:$PASS' | sudo /usr/sbin/chpasswd" 2>/dev/null

            # Conexión 5: configurar expiración
            $SSH as@"$MAQUINA" "sudo chage -M 30 '$USR'" 2>/dev/null

            log "$USR ha sido creado"

        elif [ "$OPCION" = "-s" ]
        then
            [ -z "$USR" ] && continue

            # Conexión 1: comprobar si el usuario existe
            $SSH as@"$MAQUINA" "id '$USR'" > /dev/null 2>&1
            if [ $? -ne 0 ]
            then
                #log "[$MAQUINA] El usuario $USR no existe"
                continue
            fi

            # Conexión 2: crear directorio de backup
            $SSH as@"$MAQUINA" "sudo mkdir -p /extra/backup" 2>/dev/null

            # Conexión 3: hacer backup del home
            $SSH as@"$MAQUINA" "sudo tar -cf /extra/backup/${USR}.tar -C /home '$USR'" 2>/dev/null

            # Conexión 4: eliminar usuario
            $SSH as@"$MAQUINA" "sudo /usr/sbin/userdel -r '$USR' 2>/dev/null; true" 2>/dev/null

            log "[$MAQUINA] $USR ha sido eliminado"
        fi

    done

done

exit 0