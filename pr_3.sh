#!/bin/bash
#898447, Alejaldre Martin, Hector, M, 3, B
#926915, Blanco Ramos, Nestor, M, 3, B

# Parámetros: $1: {-a|-s}, $2: <nombre_fichero>

# Comprobación de permisos
if id -nG "$USER" | grep -qw sudo
then
    echo "Este script necesita privilegios de administracion" 
    exit 1
fi

# Comprobación de parámetros
if [ "$#" -ne 2 ]
then
    echo "Número incorrecto de parámetros"
    exit 1
fi

OPCION=$1
FICHERO=$2

# Comprobar archivo de log
FECHA=$(date +"%Y_%m_%d")
USUARIO=$(whoami)

dir_destino=$(ls "$FECHA"_"$USUARIO"_provisioning.log 2>/dev/null)

if [ -z "$dir_destino" ]
then
    touch "$FECHA"_"$USUARIO"_provisioning.log
    dir_destino=$(ls "$FECHA"_"$USUARIO"_provisioning.log 2>/dev/null)
fi

if [ "$OPCION" = "-a" ]
then
# Añadir
    while IFS=',' read -r USER PASS FULLNAME || [ -n "$USER" ]
    do

        if  id "$USER" &>/dev/null 
        then
            MENSAJE="El usuario $USER ya existe"
            echo "$MENSAJE"
            echo "$MENSAJE" >> "$dir_destino"
            continue
        fi

        if ([ -z "$USER" ] || [ -z "$PASS" ] || [ -z "$FULLNAME" ] )
        then
            echo "Campo invalido"
            echo "Campo invalido" >> "$dir_destino"
            continue
        fi

        uid=$(tail -n 1 /etc/passwd | cut -d: -f3)

            if [ "$uid" -ge 1815 ]; then
                nuevo_uid=$((uid + 1))
            else
                nuevo_uid=1815
            fi
        
        /usr/sbin/useradd -m -k /etc/skel -u "$nuevo_uid" -U -c "$FULLNAME" "$USER"
        echo "$USER:$PASS" | /usr/sbin/chpasswd
        chage -M 30 "$USER"

        echo "$USER ha sido creado"
        echo "$USER ha sido creado" >> "$dir_destino"

        # Contraseña caduca en 30 días
        # Si se ha creado, escribir por pantalla el nombre completo y "ha sido creado"
        # Si el usuario ya existe, escribir por pantalla "El usuario <nombre_usuario> ya existe" y escribirlo también en el log

    done < "$FICHERO"

elif [ "$OPCION" = "-s" ]
then
# Suprimir

    mkdir -p /extra/backup

    while IFS=',' read -r USER _ || [ -n "$USER" ]
    do
    # meter el backup en /extra/backup con el nombre <nombre_usuario>.tar.gz
        if id "$USER" &>/dev/null 
        then
            if tar -cf "/extra/backup/$USER.tar" -C /home "$USER" 
            then
                /usr/sbin/userdel -r "$USER" &>/dev/null
                # Si el tar sale mal hay que hacer algo (lo pone en el último punto) 
            else 
                continue
            fi
        else
            continue
        fi
        # HAY QUE IGNORAR EL PASS Y EL FULLUSERNAME
        if ([ -z "$USER" ])
            then
                echo "Campo invalido"
                echo "Campo invalido" >> "$dir_destino"
                continue
            fi

    done < "$FICHERO"

# Comprobación de opción
else
    echo "Opción invalida" >&2
    exit 1
fi

exit 0