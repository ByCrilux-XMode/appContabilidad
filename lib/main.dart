
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'config.dart';

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
  //
  @override
  Widget build(BuildContext context) {
    Size size = MediaQuery
        .of(context)
        .size;
    double alto = size.height;
    double ancho = size.width;
    double iconsLetra = (alto + ancho) /
        4; //*0.08 para letras y 0.1 para iconos
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
                        SizedBox(height: 10),
                        //boton iniciar sesion
                        ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              minimumSize: Size(ancho * 0.5, 50),
                              foregroundColor: Theme
                                  .of(context)
                                  .colorScheme
                                  .surface,
                              backgroundColor: Theme
                                  .of(context)
                                  .colorScheme
                                  .onSurface,
                            ),
                            onPressed: () async {
                              if (_LlaveForm.currentState!.validate()) {
                                _LlaveForm.currentState!.save();
                               await _login(_usuario, _contrasena);
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
  Future<void> _login(String usuario, String contrasena) async {
    final url = Uri.parse('${Config.baseUrl}/auth/login/');
    final response = await http.post(url,
      headers: {"Content-Type": "application/json"},
      body: jsonEncode({
        "username": usuario, "password": contrasena
      })
    );
    print(response.body);
  }
}

