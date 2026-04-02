#!/bin/bash
#898447, Alejaldre Martin, Hector, M, 3, B
#926915, Blanco Ramos, Nestor, M, 3, B

# Parámetros: $1: {-a|-s}, $2: <fichero_usuarios>, $3: <fichero_máquinas>

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

if [ ! -f "$LOG_FILE" ]
then
    touch "$LOG_FILE"
fi

# Iterar sobre cada máquina
while IFS= read -r MAQUINA || [ -n "$MAQUINA" ]
do
    [ -z "$MAQUINA" ] && continue

    # Comprobar si la máquina es accesible
    ssh -i ~/.ssh/id_as_ed25519 as@"$MAQUINA" "true" &>/dev/null
    if [ $? -ne 0 ]
    then
        echo "$MAQUINA no es accesible"
        echo "$MAQUINA no es accesible" >> "$LOG_FILE"
        continue
    fi

    if [ "$OPCION" = "-a" ]
    then
        while IFS=',' read -r USR PASS FULLNAME || [ -n "$USR" ]
        do
            [ -z "$USR" ] && [ -z "$PASS" ] && [ -z "$FULLNAME" ] && continue

            if [ -z "$USR" ] || [ -z "$PASS" ] || [ -z "$FULLNAME" ]
            then
                echo "[$MAQUINA] Campo invalido"
                echo "[$MAQUINA] Campo invalido" >> "$LOG_FILE"
                continue
            fi

            # Comprobar si el usuario ya existe en remoto
            ssh -i ~/.ssh/id_as_ed25519 as@"$MAQUINA" "id '$USR'" &>/dev/null
            if [ $? -eq 0 ]
            then
                echo "[$MAQUINA] El usuario $USR ya existe"
                echo "[$MAQUINA] El usuario $USR ya existe" >> "$LOG_FILE"
                continue
            fi

            # Calcular nuevo UID en remoto
            uid=$(ssh -i ~/.ssh/id_as_ed25519 as@"$MAQUINA" "tail -n 1 /etc/passwd | cut -d: -f3")
            if [ "$uid" -ge 1815 ] 2>/dev/null
            then
                nuevo_uid=$((uid + 1))
            else
                nuevo_uid=1815
            fi

            # Crear usuario en remoto
            ssh -i ~/.ssh/id_as_ed25519 as@"$MAQUINA" "
                sudo /usr/sbin/useradd -m -k /etc/skel -u $nuevo_uid -U -c '$FULLNAME' '$USR' &&
                echo '$USR:$PASS' | sudo /usr/sbin/chpasswd &&
                sudo chage -M 30 '$USR'
            "

            if [ $? -eq 0 ]
            then
                echo "[$MAQUINA] $USR ha sido creado"
                echo "[$MAQUINA] $USR ha sido creado" >> "$LOG_FILE"
            else
                echo "[$MAQUINA] Error al crear $USR"
                echo "[$MAQUINA] Error al crear $USR" >> "$LOG_FILE"
            fi

        done < "$FICHERO_USUARIOS"

    elif [ "$OPCION" = "-s" ]
    then
        ssh -i ~/.ssh/id_as_ed25519 as@"$MAQUINA" "sudo mkdir -p /extra/backup"

        while IFS=',' read -r USR _ || [ -n "$USR" ]
        do
            [ -z "$USR" ] && continue

            ssh -i ~/.ssh/id_as_ed25519 as@"$MAQUINA" "id '$USR'" &>/dev/null
            if [ $? -ne 0 ]
            then
                continue
            fi

            ssh -i ~/.ssh/id_as_ed25519 as@"$MAQUINA" "
                sudo tar -cf /extra/backup/${USR}.tar -C /home '$USR' &&
                sudo /usr/sbin/userdel -r '$USR'
            " &>/dev/null

            if [ $? -eq 0 ]
            then
                echo "[$MAQUINA] $USR ha sido eliminado"
                echo "[$MAQUINA] $USR ha sido eliminado" >> "$LOG_FILE"
            else
                echo "[$MAQUINA] Error al eliminar $USR"
                echo "[$MAQUINA] Error al eliminar $USR" >> "$LOG_FILE"
            fi

        done < "$FICHERO_USUARIOS"
    fi

done < "$FICHERO_MAQUINAS"

exit 0