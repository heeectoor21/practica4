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
 
# Iterar sobre cada máquina (descriptor 4)
while IFS= read -r MAQUINA <&4 || [ -n "$MAQUINA" ]
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
        # Iterar sobre usuarios (descriptor 3)
        while IFS=',' read -r USR PASS FULLNAME <&3 || [ -n "$USR" ]
        do
            [ -z "$USR" ] && [ -z "$PASS" ] && [ -z "$FULLNAME" ] && continue
 
            if [ -z "$USR" ] || [ -z "$PASS" ] || [ -z "$FULLNAME" ]
            then
                echo "[$MAQUINA] Campo invalido"
                echo "[$MAQUINA] Campo invalido" >> "$LOG_FILE"
                continue
            fi
 
            RESULTADO=$(ssh -i ~/.ssh/id_as_ed25519 as@"$MAQUINA" << ENDSSH
                if id '$USR' > /dev/null 2>&1
                then
                    echo "El usuario $USR ya existe"
                else
                    uid=\$(tail -n 1 /etc/passwd | cut -d: -f3)
                    if [ "\$uid" -ge 1815 ] 2>/dev/null
                    then
                        nuevo_uid=\$((uid + 1))
                    else
                        nuevo_uid=1815
                    fi
                    sudo /usr/sbin/useradd -m -k /etc/skel -u \$nuevo_uid -U -c '$FULLNAME' '$USR' &&
                    echo '$USR:$PASS' | sudo /usr/sbin/chpasswd &&
                    sudo chage -M 30 '$USR' &&
                    echo "$USR ha sido creado"
                fi
ENDSSH
)
            echo "[$MAQUINA] $RESULTADO"
            echo "[$MAQUINA] $RESULTADO" >> "$LOG_FILE"
 
        done 3< "$FICHERO_USUARIOS"
 
    elif [ "$OPCION" = "-s" ]
    then
        # Iterar sobre usuarios (descriptor 3)
        while IFS=',' read -r USR _ <&3 || [ -n "$USR" ]
        do
            [ -z "$USR" ] && continue
 
            RESULTADO=$(ssh -i ~/.ssh/id_as_ed25519 as@"$MAQUINA" << ENDSSH
                if ! id '$USR' > /dev/null 2>&1
                then
                    echo "El usuario $USR no existe"
                else
                    sudo mkdir -p /extra/backup &&
                    sudo tar -cf /extra/backup/$USR.tar -C /home '$USR' &&
                    sudo /usr/sbin/userdel -r '$USR' &&
                    echo "$USR ha sido eliminado"
                fi
ENDSSH
)
            echo "[$MAQUINA] $RESULTADO"
            echo "[$MAQUINA] $RESULTADO" >> "$LOG_FILE"
 
        done 3< "$FICHERO_USUARIOS"
    fi
 
done 4< "$FICHERO_MAQUINAS"
 
exit 0