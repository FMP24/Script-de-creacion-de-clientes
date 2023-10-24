#!/bin/bash

### Variables ###
saved_ifs="$IFS"
IFS=$'\n'
listadoms=$(virsh -c qemu:///system list --all --name 2>&1)
listaredes=$(virsh -c qemu:///system net-list --all --name 2>&1)
regexint="^[0-9]+G$"
md5random=$(echo "$RANDOM" | md5sum | head -c 15)
idu=$(id -u)
### Error handling ###

# sudo
if [[ $idu -ne 0 ]]; then
	echo "Error: Se necesitan privilegios para correr este script."
	echo " - Intenta correr: \"sudo $0 $1 $2 $3\""
	IFS="$saved_ifs"
	exit 1
fi

# sintaxis
if [[ "$#" -ne 3 ]]; then
    	echo "Uso: $0 <Nombre> <Tamaño del volumen> <Nombre de la red>"
    	IFS="$saved_ifs"
	exit 1
fi

# nombredom coincide con ya existente
if echo "$listadoms" | grep -w -o -q "$1"; then
        echo "ERROR: El dominio ya existe"
        IFS="$saved_ifs"
        exit 1
fi


# red no existe
if ! echo "$listaredes" | grep -w -o -q "$3"; then
	echo "ERROR: La red no existe."
    	IFS="$saved_ifs"
	exit 1
fi

# integers para volumen
if ! [[ "$2" =~ $regexint ]]; then
	echo "ERROR: El tamaño del volumen debe ser un numero y una unidad (Ej. 10G, 512M)"
	IFS="$saved_ifs"
	exit 1
fi

### Instrucciones ###

echo "Creando Backing Store..."
mkdir /tmp/crear-cliente/
echo " - [1/5]: Creando bootable... "
virsh -c qemu:///system vol-create-as default "$1".qcow2 "$2" --format qcow2 --backing-vol plantilla-cliente.qcow2 --backing-vol-format qcow2 > /dev/null
echo " - [2/5]: Copiando plantilla..."
cp /var/lib/libvirt/images/"$1".qcow2 /tmp/crear-cliente/"$md5random".qcow2
echo " - [3/5]: Alocando espacio del volumen... "
virt-resize --expand /dev/sda1 /var/lib/libvirt/images/"$1".qcow2 /tmp/crear-cliente/"$md5random".qcow2 > /dev/null
echo " - [4/5]: Limpiando... "
mv /tmp/crear-cliente/"$md5random".qcow2 /var/lib/libvirt/images/"$1".qcow2
echo " - [5/5]: Backing store creado en /var/lib/libirt/images/$1."

echo "Creando máquina virtual... "
virt-install --connect qemu:///system --virt-type kvm --name "$1" --os-variant debian11 --disk path=/var/lib/libvirt/images/"$1".qcow2 --memory 1024 --vcpus 1 --import --noautoconsole > /dev/null
sleep 5 # el grub de la plantilla tiene 5 segundos

echo "Configurando red..."
while :; do
        if virsh -c qemu:///system domiflist "$1" | egrep -q "vnet*" | awk '{print $5}'; then
                mac=$(virsh -c qemu:///system domiflist "$1" | egrep "vnet*" | awk '{print $5}')
                break
        fi
done
virsh -c qemu:///system detach-interface "$1" network --mac "$mac" --persistent > /dev/null
virsh -c qemu:///system attach-interface "$1" network "$3" --model virtio --persistent > /dev/null

echo "Aplicando configuración inicial... "
virsh -c qemu:///system destroy "$1" > /dev/null
sleep 3 # Para asegurarme que está bien apagada

# Esta regla es muy especifica por que no he tenido tiempo para ponerme a hacerla mas dinámica. en mi máquina está descomentada.
# echo "Introduciendo claves públicas... "
# virt-customize --connect qemu:///system --ssh-inject "root:file:/home/fran/.ssh/id_rsa.pub" --ssh-inject "root:file:/home/fran/.ssh/jdom.pub" --ssh-inject "debian:file:/home/fran/.ssh/id_rsa.pub" --ssh-inject "debian:file:/home/fran/.ssh/jdom.pub" -d "$1" > /dev/null

echo "Configurando hostname..."
virt-customize --connect qemu:///system --hostname "$1" -d "$1" > /dev/null

echo "Iniciando $1... "
virsh -c qemu:///system start "$1" > /dev/null

echo "La máquina virtual $1 ha sido creada."

# Ultimas limpiezas
rmdir /tmp/crear-cliente/
IFS="$saved_ifs"

exit 0
