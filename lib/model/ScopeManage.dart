import 'dart:io';
import 'dart:convert';
import 'dart:async';
import 'package:scoped_model/scoped_model.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'package:localstorage/localstorage.dart';
import 'package:http/http.dart' as http;
import '../Cart.dart';

class Data {
  int id;
  String nama;
  String deskripsi;
  int harga;
  String gambar;
  int shopid;
  int counter;
  int subtotal;

  Data({
    this.nama,
    this.deskripsi,
    this.harga,
    this.gambar,
  });
}

List data;

class AppModel extends Model {
  CartState cartState;
  List<Data> _data = [];
  List<Data> _cart = [];
  String cartMsg = '';
  String cartEmpty = 'Keranjang belanja anda masih kosong!';
  bool success = false;
  Database _db;
  Directory tempDir;
  String tempPath;
  final LocalStorage storage = new LocalStorage('app_data');
  final String url =
      'http://www.malmalioboro.co.id/index.php/api/produk/get_list';

  get finalprint => printCart();

  //Ambil data JSON dari API
  Future<String> fetchData() async {
    Map body = {'idtenan': '136'};
    http.Response response = await http.post(
      Uri.encodeFull(url),
      body: body,
    );
    var parse = json.decode(response.body);
    data = parse;
    createDB();
    return 'Success!';
  }

  AppModel() {
    fetchData();
  }

  //Create database cart.db
  createDB() async {
    try {
      Directory documentsDirectory = await getApplicationDocumentsDirectory();
      String path = join(documentsDirectory.path, 'cart.db');

      print(path);
      //await storage.deleteItem('isFirst');
      //await this.deleteDB();

      var database =
          await openDatabase(path, version: 1, onOpen: (Database db) {
        this._db = db;
        print('OPEN DBV');
        this.createTable();
      }, onCreate: (Database db, int version) async {
        this._db = db;
        print('DB Created');
      });
    } catch (e) {
      print('ERRR >>>>');
      print(e);
    }
  }

  //Delete database cart.db
  deleteDB() async {
    Directory documentsDirectory = await getApplicationDocumentsDirectory();
    String path = join(documentsDirectory.path, 'cart.db');

    await deleteDatabase(path);
    if (storage.getItem('isFirst') != null) {
      await storage.deleteItem('isFirst');
    }
  }

  //Buat tabel item_list & cart_list jika belum ada tabel
  createTable() async {
    try {
      var qry = 'CREATE TABLE IF NOT EXISTS item_list ( '
          'id INTEGER PRIMARY KEY,'
          'nama TEXT,'
          'deskripsi TEXT,'
          'harga INT,'
          'gambar TEXT,'
          'datetime DATETIME)';
      await this._db.execute(qry);
      qry = 'CREATE TABLE IF NOT EXISTS cart_list ( '
          'id INTEGER PRIMARY KEY,'
          'shopid INTEGER,'
          'nama TEXT,'
          'deskripsi TEXT,'
          'harga INT,'
          'gambar TEXT,'
          'counter INT,'
          'subtotal INT,'
          'datetime DATETIME)';

      await this._db.execute(qry);

      var _flag = storage.getItem('isFirst');
      print('FLAG IS FIRST $_flag');
      if (_flag == 'true') {
        this.fetchLocalData();
        this.fetchCartList();
      } else {
        this.insertInLocal();
      }
    } catch (e) {
      print('ERRR ^^^');
      print(e);
    }
  }

  //Isi data item dari API ke dalam tabel item_list & list array _data
  insertInLocal() async {
    try {
      await this._db.transaction((tx) async {
        for (var i = 0; i < data.length; i++) {
          print('Called insert $i');
          Data d = new Data();
          d.id = i + 1;
          d.nama = data[i]['nama'];
          d.deskripsi = data[i]['deskripsi'];
          d.gambar = data[i]['gambar'];
          d.harga = int.parse(data[i]['harga']);
          try {
            var qry =
                "INSERT INTO item_list(nama, deskripsi, harga, gambar) VALUES('${d.nama}', '${d.deskripsi}', ${d.harga}, '${d.gambar}')";
            var _res = await tx.rawInsert(qry);
          } catch (e) {
            print('ERRR >>>');
            print(e);
          }
          _data.add(d);
          notifyListeners();
        }
        storage.setItem('isFirst', 'true');
      });
    } catch (e) {
      print('ERRR ## > ');
      print(e);
    }
  }

  //Ambil record item dari tabel item_list
  fetchLocalData() async {
    try {
      List<Map> list = await this._db.rawQuery('SELECT * FROM item_list');
      list.map((dd) {
        Data d = new Data();
        d.id = dd['id'];
        d.nama = dd['nama'];
        d.deskripsi = dd['deskripsi'];
        d.gambar = dd['gambar'];
        d.harga = dd['harga'];
        _data.add(d);
      }).toList();
      notifyListeners();
    } catch (e) {
      print('ERRR %%%');
      print(e);
    }
  }

  //Isi tambah list array _cart dari list array _data
  void addCart(Data dd) {
    print(dd);
    print(_cart);
    int _index = _cart.indexWhere((d) => d.shopid == dd.id);
    if (_index > -1) {
      success = false;
      cartMsg = '${dd.nama.toUpperCase()} sudah ada di keranjang belanja.';
    } else {
      this.insertInCart(dd);
      success = true;
      cartMsg =
          '${dd.nama.toUpperCase()} berhasil ditambahkan ke keranjang belanja.';
    }
  }

  //Isi tabel cart_list dari list array _data
  insertInCart(Data d) async {
    await this._db.transaction((tx) async {
      try {
        var qry =
            "INSERT INTO cart_list(shopid, nama, deskripsi, harga, gambar, counter, subtotal) VALUES (${d.id},'${d.nama}', '${d.deskripsi}', ${d.harga},'${d.gambar}', ${d.counter}, ${d.subtotal})";
        var _res = await tx.execute(qry);
        this.fetchCartList();
      } catch (e) {
        print('ERRR @@ @@');
        print(e);
      }
    });
  }

  //Ambil record item dari tabel cart_list
  fetchCartList() async {
    try {
      _cart = [];
      List<Map> list = await this._db.rawQuery('SELECT * FROM cart_list');
      print('Cart len ${list.length.toString()}');
      list.map((dd) {
        Data d = new Data();
        d.id = dd['id'];
        d.nama = dd['nama'];
        d.deskripsi = dd['deskripsi'];
        d.harga = dd['harga'];
        d.gambar = dd['gambar'];
        d.counter = dd['counter'];
        d.subtotal = dd['subtotal'];
        d.shopid = dd['shopid'];
        _cart.add(d);
      }).toList();
      notifyListeners();
    } catch (e) {
      print('ERRR @##@');
      print(e);
    }
  }

  //Item listing to Home()
  List<Data> get itemListing => _data;

  //Tambah item (next implementation)
  void addItem(Data dd) {
    Data d = new Data();
    d.id = _data.length + 1;
    d.nama = 'nama';
    d.deskripsi = 'deskripsi';
    d.gambar = 'http://malmalioboro.co.id';
    d.harga = 1500;
    d.counter = 1;
    _data.add(d);
    notifyListeners();
  }

  //Cart listing to Cart()
  List<Data> get cartListing => _cart;

  //Delete record dari tabel cart_list jika ada item yang dihapus
  removeCartDB(Data d) async {
    try {
      var qry = 'DELETE FROM cart_list where id = ${d.id}';
      this._db.rawDelete(qry).then((data) {
        print(data);
        int _index = _cart.indexWhere((dd) => dd.id == d.id);
        _cart.removeAt(_index);
        notifyListeners();
      }).catchError((e) {
        print(e);
      });
    } catch (e) {
      print('ERR rm cart$e');
    }
  }

  // Remove Cart
  void removeCart(Data dd) {
    this.removeCartDB(dd);
  }

  printCart() {}
}
