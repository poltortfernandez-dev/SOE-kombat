# Moro Kombat

Juego de lucha con Riki, Paul, Congui, Miro, Moya y Pons.
La exportación web está en esta carpeta. El código editable de Godot está en source.

## Publicarlo en un repositorio nuevo

1. En GitHub crea un repositorio vacío llamado moro-kombat y selecciona Public. Las imágenes del juego estarán disponibles en internet. En una cuenta gratuita, Pages se publica desde un repositorio público.
2. Clónalo con GitHub Desktop. Copia TODO el contenido de esta carpeta dentro del repositorio recién clonado. index.html debe quedar directamente en la raíz, junto a index.pck, index.wasm y el resto de archivos. Conserva source para editar el proyecto.
3. En GitHub Desktop escribe «Primera versión de Moro Kombat», pulsa Commit to main y después Push origin. Usa Desktop para subir los archivos grandes del motor.
4. En la web del repositorio abre Settings → Pages. En Source selecciona Deploy from a branch, elige main y /(root), y pulsa Save.
5. Espera a que termine la publicación en Actions. Pages mostrará el enlace https://TU-USUARIO.github.io/moro-kombat/.

Al actualizar el juego, reemplaza los archivos exportados de la raíz y repite Commit y Push.

## Jugar

A/D o flechas para desplazarse. J para puño. K para patada.
Espacio o L para bloquear. Esc para pausar.
Pulsa TÚ o RIVAL y después un retrato para elegir cada personaje.
La web incluye combate contra la máquina y online para dos jugadores por código.

## Jugar online desde Pages

1. Ambos abrís el mismo enlace HTTPS de Pages y elegís vuestro personaje.
2. Entrad en Online por código. Un jugador pulsa Crear sala y comparte su código MK-XXXXXX-XXXXXX.
3. El segundo pega el código y pulsa Unirme a la sala. El anfitrión acepta la invitación.
4. Al acabar, ambos podéis pulsar Pedir revancha sin crear otra sala.

Mantened ambas pestañas abiertas y en primer plano durante la partida.
El encuentro usa el servicio público gratuito de PeerJS. WebRTC intenta conectar directamente y conserva los servidores STUN/TURN predeterminados de PeerJS como ayuda a la conexión.
La disponibilidad y la latencia dependen de las redes y de servicios externos gratuitos. Algunas redes corporativas o móviles pueden impedir la conexión. El juego muestra un aviso si la sala no es accesible.
No se necesita cuenta, instalar aplicaciones ni configurar el router.
La comprobación realizada usa dos pestañas de Chrome en el mismo Mac. La conexión entre dos hogares sigue pendiente de prueba.
PeerJS se distribuye bajo MIT. Consulta PeerJS-LICENSE.txt.


## Editar el juego

Abre source/project.godot con Godot 4.7.2.
Para actualizar la web, exporta con el preset Web y guarda index.html en la raíz de este repositorio, sustituyendo los archivos anteriores.
Para generar aplicaciones con salas online, también hacen falta los conectores de escritorio de Cloudflare del proyecto de desarrollo.

Configuración oficial de Pages
https://docs.github.com/en/pages/getting-started-with-github-pages/configuring-a-publishing-source-for-your-github-pages-site
