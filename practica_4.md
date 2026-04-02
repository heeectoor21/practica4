# Cosas a hacer

- Hay que hacer dos interfaces
- Comprobar que funcionan con ping 
- Instalar ssh
- Hacer que root no pueda conectarse en remoto 


Hay que incluir las comprobaciones de ping y tal en este documento.

Hay que indicar en este documento las máquinas virtuales que has utilizado con sus direcciones IP e identificadores MAC. Las IPs de las máquinas remotas deben ser 192.168.56.11 y 192.168.56.12 para poder pasar los test.

Para la parte 2:

Hemos configurado las interfaces enp0s3 y enp0s8 (aunque la primera ya estaba configurada) en el fichero /etc/network/interfaces. Añadiendo en las máquinas virtuales auto enp0s8, y iface enp0s8 inet static address 192.168.56.xx (xx = 10, 11, 12 para las distintas máquinas, 10 es el host) netmask 255.255.255.0.

Hemos hecho un ping 

Ya teníamos instalado el ssh

Para que ssh no permita el login con root, hemos editado /etc/ssh/sshd_config y le hemos editado la línea correspondiente para que ahora diga "PermitRootLogin no"

Finalmente comprobamos que todo funcionase perfectamente.

Para la parte 3:

Hemos generado un par de claves con ssh-keygen -t ed25519 -f ~/.ssh/id_as_ed25519, luego hemos copiado la clave pública a la máquina correspondiente mediante ssh-copy-id -i ~/.ssh/id_as_ed25519.pub as@192.168.56.11.

Comprobamos que nos podemos conectar mediante ssh -i ~/.ssh/id_as_ed25519 as@192.168.56.11

Hemos hecho lo mismo para la otra máquina virtual. Lo único que cambia en los comandos es que en vez de 11 hay un 12.