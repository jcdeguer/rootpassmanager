#!/bin/sh
#
# Este script se encarga de cambiar la clave de root
# en todos los equipos con la clase rootmanager activa.
#
# Changelogs
# Version: 1.0
#
# Fecha: 31/08/2017
# Equipo de Plataforma Tecnologica
#
#################################################################

USER=
PASS=
PARAM_ID=
DOMINIO= # SE DEBE DEFINIR EL DOMINIO
PUPPET_CLASS_NAME=rootpassmanager
VARIABLE_CLASS_NAME=root_password

clear
echo "####################################################"
echo "#                                                  #"
echo "#      Gestion centralizada de claves de root      #"
echo "#                                                  #"
echo "####################################################"
echo " "

#################################################################################
#    INICIO DE FUNCIONES

funcion_check_id_parameter(){
 # Valida el ID actual del parametro encargado de almacenar la clave de root
 PARAM_ID=$(hammer -u $USER -p $PASS puppet-class sc-params --puppet-class $PUPPET_CLASS_NAME | grep "$VARIABLE_CLASS_NAME" | cut -d "|" -f 1)
}

funcion_lista_equipos_habilitados(){
# Se validan los equipos con la clase que cambia la clave de root. Solo guarda en una variable un equipo al lado del otro.
 hammer -u $USER -p $PASS host list --search "class = $PUPPET_CLASS_NAME" | grep "$DOMINIO" | cut -d "|" -f 2
}

funcion_ver_equipos_clave_root_definida(){
# Esta funcion genera una lista de todos los equipos que tienen una clave definida con Puppet.
# En este punto se obtiene el ID del parametro que se debe validar en la BASE.
 funcion_check_id_parameter
# Aca se genera el listado filtrando la informacion basura para dejar un listado ordenado del tipo "SERVER - PASS".
 hammer -u $USER -p $PASS sc-param info --id $PARAM_ID | awk '/Match:|Value:/{print $2}' | grep -v Value | awk -v RS= '/fqdn*$DOMINIO*/{next}{gsub(/\n/,",")}1' | sed -e s/'fqdn\='/\\n/g | cut -d ',' -f 1,2 | sed -e s/','/\\t/g | cut -d \" -f 1 | sort -u | grep "$DOMINIO"
}

funcion_lista_equipos_a_cambiar_clave(){
# Esta funcion genera una lista precisa de aquellos equipos a los cuales se les debe generar una clave de root.
# En este punto se llama a la funcion para generar la lista de servidores habilitados y guarda la misma en un archivo temporal.
 funcion_lista_equipos_habilitados | sort | awk '{print $1}' > /root/temp_hab
# Se llama la funcion que genera la lista de servidores con clave de root definida y la guarda en un archivo temporal.
 funcion_ver_equipos_clave_root_definida > /root/temp_act
# Genero el archivo donde se guardara la lista definitiva de equipos a los que se debe generar una clave de root.
 touch /root/temp_list; > /root/temp_list
# Guardo la lista en un archivo temporal y ordenado que se analizara luego.
 cat /root/temp_act | sort | awk '{print $1}' > /root/temp_listactsort
# Se analiza la lista para separar los equipos a los que se les debe definir una clave de root.
 cat /root/temp_hab | while read EQUIPO_HAB
 do
# Se revisa si el equipo existe en la lista, si existe significa que no debemos definirle una.
 if grep -Fxq "$EQUIPO_HAB" /root/temp_listactsort
 then
# Solo emite un mensaje para que el operador del Script sepa lo que sucede.
  echo "" #El equipo $EQUIPO_HAB ya se encuentra en la lista activa, no es necesario tomar acciones."
 else
# Agrega el equipo que no tiene clave de root definida en la cola para que se le asigne una.
  echo $EQUIPO_HAB >> /root/temp_list
 fi
 done
# Se elimina el archivo usado, ya que no es necesario.
 > /root/temp_listactsort; rm -f /root/temp_listactsort
}

funcion_generador_nuevas_claves(){
# Esta Funcion se encarga de tomar la lista de equipos generada por la funcion funcion_lista_equipos_a_cambiar_clave y le define una clave de root a cada equipo.
# Se crea y purga el archivo temporal.
touch /root/temporal; > /root/temporal
# Aqui se llama a la funcion para generar la lista temporal.
 funcion_lista_equipos_a_cambiar_clave
 cat /root/temp_list | while read EQUIPO
 do
# Se define la clave de root con una complejidad estandar de 8 caracteres dos digitos, tres mayusculas, y cero signos.
  NEW_PASS=$(mkpasswd -l 8 -d 2 -C 3 -s 0)
# Se genera la lista de equipos y claves de root que se guardara en el archivo temporal.
  echo " $EQUIPO        $NEW_PASS "
 done > /root/temporal
 cat /root/temporal | while read EQUIPO
 do
  echo "$EQUIPO "
 done
}

funcion_cambiar_clave_root(){
# Esta funciona ejecuta el de la clave de root efectivo, al definirlo en la variable de Puppet, el impacto en el nodo se hara efectivo cuando solicite actualizacion al Puppet Master.
  echo " "
# Se llama la funcion que valida el ID del parametro de Puppet.
  funcion_check_id_parameter
# Se llama a la funcion que genera el listado SERVER - PASS que sera usado.
  funcion_generador_nuevas_claves
# Ciclo repetitivo por cada equipo, aca se ejecuta la actualizacion de la clave de root al nodo.
  cat /root/temporal | while read SERVER PASS_E
  do
    echo " Cambiando clave de $SERVER "
# Este es el comando usado por Foreman para impactar cambios en las variables del Puppet Master.
    hammer -u $USER -p $PASS sc-param add-override-value --smart-class-parameter-id $PARAM_ID --match fqdn=$SERVER --value $PASS_E 2>&1>/dev/null && echo " Cambiado ok " || echo "No es necesario cambiar la clave en $SERVER "
  done
}

funcion_pedir_user_y_pass(){
 echo "##################################################################"
 echo "#                                                                #"
 echo "#  Para continuar, debe ingresar USER y PASS, valido en Foreman  #"
 echo "#                                                                #"
 echo "##################################################################"
 echo -n " Enter username: "; read USER
 USER=$USER
 #echo -n " Bienvenido $USER, ingrese su password: "; read PASS
 unset PASS
 PROMPT=" Welcome $USER, enter your password:"
 while IFS= read -p "$PROMPT" -r -s -n 1 char
 do
  if [[ $char == $'\0' ]]
  then
   break
  fi
  PROMPT='*'
  PASS+="$char"
 done
 PASS=$PASS
 echo " "
}

#    FIN DE FUNCIONES
#################################################################################

#################################################################################
#    INICIO DE MENU DE OPCIONES
case "$1" in
 --interactive)
  funcion_pedir_user_y_pass
  while read respuesta
  do
   clear
   echo " "
   echo " ############################################################### "
   echo " #                                                             # "
   echo " #    El siguiente menu permite revisar las claves de root     # "
   echo " #                                                             # "
   echo " #  Elegir que desea hacer usando las letras en los corchetes  # "
   echo " #                                                             # "
   echo " # [a/A] - Listar equipos con clave clave de root definida.    # "
   echo " # [l/L] - Listar equipos sin clave de root segura.            # "
   echo " # [c/C] - Ejecutar cambio de clave en los equipos listados.   # "
   echo " # [g/G] - Realizar una prueba de complejidad de claves.       # "
   echo " # [r/R] - Generar un reporte de estado y enviarlo por e-mail. # "
   echo " #                                                             # "
   echo " #   [s/S] - Salir sin realizar cambios.                       # "
   echo " #                                                             # "
   echo " ############################################################### "
   echo -n "Su opcion: "; read respuesta
   case "$respuesta" in
    [aA])
     clear
     echo "################################################"
     echo "# "
     echo "# Listado de equipos con clave root definida "
     echo "# "
     echo "#  SERVER             ||      CLAVE "
     echo "# "
     funcion_ver_equipos_clave_root_definida | while read SERVER PASS
     do
      echo "#  $SERVER           $PASS  "
     done
     echo "# "
     echo "################################################"
     rm -f /root/temporal /root/temp_act /root/temp_hab /root/temp_list
    ;;
    [lL])
     clear
     echo "################################################"
     echo "# "
     echo "#  Listado de equipos sin clave root definida "
     echo "# "
     echo "#  SERVER "
     echo -n "# "
     funcion_lista_equipos_a_cambiar_clave
     cat /root/temp_list | grep $DOMINIO | while read SERVER
     do
      echo "# $SERVER "
     done
     echo "# "
     echo "#  Si aparecieron equipos, se debera ejecutar"
     echo "#  el cambio de su clave por una compleja. "
     echo "# "
     echo "################################################"
     rm -f /root/temporal /root/temp_act /root/temp_hab /root/temp_list
    ;;
    [cC])
     clear
     echo "######################################################################"
     echo "# "
     echo "#  Generando cambio de clave de root en los nodos... "
     echo "# "
     funcion_cambiar_clave_root | while read SALIDA
     do
      echo "# $SALIDA "
     done
     echo "# "
     echo "#  NOTA: Si aparece algun equipo, significa que se realizo el cambio. "
     echo "#  Para ver el estado final usar la opcion [a/A] "
     echo "# "
     echo "######################################################################"
     rm -f /root/temporal /root/temp_act /root/temp_hab /root/temp_list
    ;;
    [gG])
     clear
     echo "##############################################################"
     echo "# "
     echo "#  Listado de prueba de equipos con clave root provisoria  "
     echo "# Esta prueba sirve para verificar la complejidad de la clave "
     echo "# "
     echo "#  SERVER "
     echo "# "
     funcion_generador_nuevas_claves | while read SALIDA
     do
      echo "# $SALIDA "
     done
     echo "# "
     echo "#  NOTA: Estas claves se borraran, NO son definitivas."
     echo "#  Para cambiar la clave de root se debera elegir: [c/C] "
     echo "# "
     echo "##############################################################"
     rm -f /root/temporal /root/temp_act /root/temp_hab /root/temp_list
    ;;
    [rR])
     clear
     echo " ##################################################################### "
     echo " #                                                                   # "
     echo " #   Pero, espera desesperado, todavia no se implemento el reporte   # "
     echo " #                                                                   # "
     echo " ##################################################################### "
     echo " "
     exit
    ;;
    [sS])
     clear
     echo " "
     echo " Saliendo al mundo real.. see ya later, aligator! "
     echo " "
     break
     exit
    ;;
    *)
     esperar=3
     while (test "$esperar" -gt 0)
     do
      clear
      echo " Solo se aceptan las opciones (a,A,l,L,c,C,g,G,r,R,s, y/o S) "
      echo " vuelva a intentarlo en $esperar segundos..."
      echo " Presione [ENTER] para continuar... "
      sleep 1
      esperar=$((esperar-1))
     done
    ;;
   esac
  done
  rm -f /root/temporal /root/temp_act /root/temp_hab /root/temp_list
 ;;
 --quiet)
  case "$2" in
   -a)
    clear
    funcion_pedir_user_y_pass
    sleep 2
    echo "################################################"
    echo "# "
    echo "# Listado de equipos con clave root definida "
    echo "# "
    echo "#  SERVER             ||      CLAVE "
    echo "# "
    funcion_ver_equipos_clave_root_definida | while read SERVER PASS
    do
     echo "#  $SERVER           $PASS  "
    done
    echo "# "
    echo "################################################"
    rm -f /root/temporal /root/temp_act /root/temp_hab /root/temp_list
   ;;
   -l)
    clear
    funcion_pedir_user_y_pass
    sleep 2
    echo "################################################"
    echo "# "
    echo "#  Listado de equipos sin clave root definida "
    echo "# "
    echo "#  SERVER "
    echo "# "
    funcion_lista_equipos_a_cambiar_clave | while read SERVER
    do
     echo "# $SERVER "
    done
    echo "# "
    echo "#  Si aparecieron equipos, se debera ejeuctar"
    echo "#  $0 --quiet -c "
    echo "# "
    echo "################################################"
    rm -f /root/temporal /root/temp_act /root/temp_hab /root/temp_list
   ;;
   -c)
    clear
    funcion_pedir_user_y_pass
    sleep 2
    echo "######################################################################"
    echo "# "
    echo "#  Generando cambio de clave de root en los nodos... "
    echo "# "
    funcion_cambiar_clave_root | while read SALIDA
    do
     echo "# $SALIDA "
    done
    echo "# "
    echo "#  NOTA: Si aparece algun equipo, significa que se realizo el cambio. "
    echo "#  Para ver el estado final usar: "
    echo "#  $0 --quiet -a "
    echo "# "
    echo "######################################################################"
    rm -f /root/temporal /root/temp_act /root/temp_hab /root/temp_list
    exit
   ;;
   -g)
    clear
    funcion_pedir_user_y_pass
    sleep 2
    echo "###########################################################"
    echo "# "
    echo "#  Listado de prueba de equipos con clave root provisoria  "
    echo "# "
    echo "#  SERVER "
    echo "# "
    funcion_generador_nuevas_claves | while read SALIDA
    do
     echo "# $SALIDA "
    done
    echo "# "
    echo "#  NOTA: Estas claves se borraran, no son definitiva."
    echo "#  Para cambiar la clave se debera usar: "
    echo "#  $0 --quiet -c "
    echo "# "
    echo "###########################################################"
    rm -f /root/temporal /root/temp_act /root/temp_hab /root/temp_list
    exit
   ;;
   *)
    echo "La opcion elegida es invalida, se debe usar solo: "
    echo -e " - Usar $0 --interactive\tPara abrir el menu y navegar entre las opciones."
    echo -e " - Usar $0 --quiet\t <SUB_OPCION> para realizar una accion automatica."
    echo -e " --- Usar $0 --quiet -a\tPara listar los equipos que tienen una clave de root definida."
    echo -e " --- Usar $0 --quiet -l\tPara listar los equipos que aun no tienen clave de root compleja."
    echo -e " --- Usar $0 --quiet -c\tPara ejecuta el cambio de clave de root en los equipos listados."
    echo -e " --- Usar $0 --quiet -g\tPara realizar una prueba de complejidad de claves."
    echo -e " --- Usar $0 --quiet -r\tPara generar un reporte de estado actual y enviarlo por e-mail."
    echo -e " --- Usar $0 --quiet -f\tPara ejecutar "
    exit
   ;;
  esac
 ;;
 *)
  echo "Opcion invalida: "
  echo -e " - Usar $0 --interactive\tPara abrir el menu y navegar entre las opciones."
  echo -e " - Usar $0 --quiet\t <SUB_OPCION> para realizar una accion automatica."
  echo -e " --- Usar $0 --quiet -a\tPara listar los equipos que tienen una clave de root definida."
  echo -e " --- Usar $0 --quiet -l\tPara listar los equipos que aun no tienen clave de root compleja."
  echo -e " --- Usar $0 --quiet -c\tPara ejecuta el cambio de clave de root en los equipos listados."
  echo -e " --- Usar $0 --quiet -g\tPara realizar una prueba de complejidad de claves."
  echo -e " --- Usar $0 --quiet -r\tPara generar un reporte de estado actual y enviarlo por e-mail."
  echo -e " --- Usar $0 --quiet -f\tPara ejecutar "
 exit;;
esac
#    FIN DE MENU DE OPCIONES
#################################################################################

rm -f /root/temporal /root/temp_act /root/temp_hab /root/temp_list
