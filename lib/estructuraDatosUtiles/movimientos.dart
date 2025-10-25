class movimientosConfig{
  int? count;
  String? next;
  String? previous;

  void setCount(int v){
    count = v;
  }

  void setNext(String v){
    next = v;
  }

  void setPrevious(String v){
    previous = v;
  }

  int getCount(){
    return count!;
  }

  String getNext(){
    return next!;
  }

  String getPrevious(){
    return previous!;
  }

}