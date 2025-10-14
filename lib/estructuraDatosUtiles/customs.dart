
class Custom{
  String? _colorPrimario; String? _colorSecundario; String? _colorTerciario;
  double? _ancho; double? _alto;
  //sets
  void setColorPrimario(String color){
    _colorPrimario = color;
  }
  void setColorSecundario(String color){
    _colorSecundario = color;
  }
  void setColorTerciario(String color){
    _colorTerciario = color;
  }
  void setAncho(double ancho){_ancho = ancho;
  }
  void setAlto(double alto){
    _alto = alto;
  }
  //gets
  String getColorPrimario(){
    return _colorPrimario!;
  }
  String getColorSecundario(){
    return _colorSecundario!;
  }
  String getColorTerciario(){
    return _colorTerciario!;
  }
  double getAncho(){
    return _ancho!;
  }
  double getAlto() {
    return _alto!;
  }
  double getTamanoLetra(){
    return ((_ancho! * _alto!) / 4)*0.08;
  }
  double getTamanoIcono(){
    return ((_ancho! * _alto!) / 4)*0.1;
  }

}