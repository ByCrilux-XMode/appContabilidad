
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'config.dart';
import 'elegirEmpresa.dart';

void main() { //el arrancador
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});
  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Contabilidad',
      theme:ThemeData.light(),
      home: PantallaLogin(),
    );
  }
}

class PantallaLogin extends StatefulWidget { //constructor de la pantalla
  const PantallaLogin({super.key});
  @override
  State<PantallaLogin> createState() => _PantallaLoginState();
}

class _PantallaLoginState extends State<PantallaLogin> { //mi pantalla de login que va cambiar
  //variables
  final _LlaveForm = GlobalKey<FormState>();
  bool _contrasenaVisible = true; //verdadero por default
  String _usuario = ''; String _contrasena = ''; //para guardar esos parametros
  bool _estaCargando = false; //indicador de login en false
  //
  @override
  Widget build(BuildContext context) {
    Size size = MediaQuery.of(context).size;
    double alto = size.height;
    double ancho = size.width;
    double iconsLetra = (alto + ancho) / 4; //*0.08 para letras y 0.1 para iconos
    return Scaffold( //LA PANILLA
      body: SafeArea( //cuerpo
          child: Padding( //padding para alejarnos de los Bordes (estilo nada mas)
              padding: EdgeInsets.all(50), //separacion del borde de la pantalla
              child: Align( //para centrar
                alignment: Alignment.center,
                child: Form( // formulario
                    key: _LlaveForm,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        //icono
                        Icon(Icons.balance, size: iconsLetra * 0.3),
                        //finicono
                        SizedBox(height: 10),
                        //username
                        TextFormField(
                          decoration: InputDecoration( //necesario para decoraciiones
                            labelText: 'usuario',
                            //texto de la cajita
                            labelStyle: TextStyle(fontSize: iconsLetra * 0.08),
                            prefixIcon: Icon(
                              Icons.person, size: iconsLetra * 0.1,),
                            //icono dentro la cajita
                            border: OutlineInputBorder( //borde
                                borderRadius: BorderRadius.circular(10)
                            ),
                          ),
                          validator: (v) { // validador
                            if (v == null || v.isEmpty) {
                              return 'Ingrese Usuario';
                            } else {
                              return null;
                            }
                          },
                          onSaved: (v) { //guarda el valor
                            _usuario = v!;
                          },
                        ),
                        //fin username
                        SizedBox(height: 10),
                        //password
                        TextFormField(
                          obscureText: _contrasenaVisible,
                          //pasa que la constrasena no se vea
                          decoration: InputDecoration( //necesario para decoraciiones
                            prefixIcon: Icon(
                              Icons.lock, size: iconsLetra * 0.1,),
                            //icono dentro la cajita
                            labelText: 'contraseña',
                            //texto de la cajita
                            labelStyle: TextStyle(fontSize: iconsLetra * 0.08),
                            suffixIcon: IconButton(
                                onPressed: () { //logica para mostrar o no la contrasena
                                  setState(() {
                                    _contrasenaVisible = !_contrasenaVisible;
                                  });
                                }, icon: Icon(_contrasenaVisible ? Icons
                                .visibility : Icons.visibility_off,
                              size: iconsLetra * 0.1,)),
                            border: OutlineInputBorder( //borde
                                borderRadius: BorderRadius.circular(10)
                            ),
                          ),
                          validator: (v) { // validador
                            if (v == null || v.isEmpty) {
                              return 'Ingrese Usuario';
                            } else {
                              return null;
                            }
                          },
                          onSaved: (v) {
                            _contrasena = v!;
                          },
                        ),
                        //fin password
                        SizedBox(height: 30),
                        _estaCargando? CircularProgressIndicator(): //aqui es un if comprimido
                        //boton iniciar sesion
                        ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              minimumSize: Size(ancho * 0.5, 50),
                              foregroundColor: Theme.of(context).colorScheme.surface,
                              backgroundColor: Theme.of(context).colorScheme.onSurface,
                            ),
                            onPressed: () async {
                              if (_LlaveForm.currentState!.validate()) {
                                _LlaveForm.currentState!.save();
                                bool ingreso = await _login(_usuario, _contrasena);
                                if (ingreso){
                                  Navigator.push(context, MaterialPageRoute(builder: (context) => ElegirEmpresa()),
                                  );
                                }
                              }
                            },
                            child: Text('Iniciar Sesion',
                              style: TextStyle(fontSize: iconsLetra * 0.08),)
                        ),
                        //boton iniciar sesion
                      ],
                    )
                ), //fin formulario
              ) //fin centrar
          ) //fin padding
      ),
    ); //fin Scaffold
  }

  Future<bool> _login(String usuario, String contrasena) async {
    final url = Uri.parse('${Config.baseUrl}/auth/login/');
    setState((){
      _estaCargando = true; //primero se muestra el indicador de cargando
    });
    // 3 estados
    try { //1= intento
      final response = await http.post(url,
          headers: {"Content-Type": "application/json"},
          body: jsonEncode({
            "username": usuario, "password": contrasena
          })
      );
      if (response.statusCode == 200){
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Inicio Exitoso'),
          ),
        );
        //guardar algunos datos importantes del responde
        final bodyString = response.body; //el body de responde se va a esa variabvke
        final Map<String, dynamic> datos = jsonDecode(bodyString); //se hace el decode y se lo mapea
        _guardarDatos(datos); //void abajo
        //fin del guardado
        return true;
      }else{
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Usuario o Contraseña Incorrecta'),
          ),
        );
      }

    }catch (valor) { //2= el error
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: ${valor.toString()}'),
        ),
      );
      return false;
    }finally{ //3=como final
      setState((){
        _estaCargando = false; //para el indicador
      });
    }
    return false;
  }
   Future<void> _guardarDatos(Map<String, dynamic> datos) async { //accede a los datos del htpps con  datos['Xcampo']
    final save = await SharedPreferences.getInstance();
    await save.setString('access', datos['access']);
    await save.setString('username', datos['username']);
    await save.setString('nombre', datos['nombre']);
    await save.setString('apellido, ', datos['apellido']);
    await save.setString('email',datos['email']);
  }
}
