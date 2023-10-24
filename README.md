# Script-de-creacion-de-clientes
**Script para la práctica de virtualización de 2º ASIR en el IES Gonzalo Nazareno.**

Este script tiene las siguientes limitaciones:
1. No funcionara sin una plantilla .qcow2 apropiada en /var/lib/libvirt/images/ de nombre "plantilla-cliente.qcow2"
2. Puede dar problemas si el tamaño seleccionado para el disco es menor a 3GB
3. El tamaño del disco a crear no está limitado mas allá de las limitaciones que pone libvirt.
