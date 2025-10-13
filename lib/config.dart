import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
class Config { //si estamos en desarrollo usar http://10.0.2.2:8080

  static const String baseUrl = "https://contabackoficial-393159630636.northamerica-south1.run.app";

  Future<void> GuardarAlgunDato(String clave,dynamic valor) async{
    final dato = await SharedPreferences.getInstance();
    if (valor is int){
      await dato.setInt(clave, valor);
    }else if ( valor is double){
      await dato.setDouble(clave, valor);
    }else if (valor is bool){
      await dato.setBool(clave, valor);
    }else if (valor is String){
      await dato.setString(clave, valor);
    }else if (valor is List<String>){
      await dato.setStringList(clave, valor);
    }else{
      AlertDialog(title: Text('Error'), content: Text('Tipo de dato no soportado'));
      print('---------------------------------dato no soportado-----------------------------------------');
    }
  }

  Future<dynamic> obtenerDato(String clave) async{
    final dato = await SharedPreferences.getInstance();
    return dato.get(clave);
  }

}