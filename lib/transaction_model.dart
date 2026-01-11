class TransactionModel {
  final int? id;
  final String title; // Judul transaksi (misal: Beli Makan)
  final double amount; // Jumlah uang
  final String type; // 'Pemasukan', 'Pengeluaran', 'Transfer'
  final DateTime date;
  final String description;

  TransactionModel({
    this.id,
    required this.title,
    required this.amount,
    required this.type,
    required this.date,
    this.description = '',
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'amount': amount,
      'type': type,
      'date': date.toIso8601String(),
      'description': description,
    };
  }

  factory TransactionModel.fromMap(Map<String, dynamic> map) {
    return TransactionModel(
      id: map['id'],
      title: map['title'],
      amount: map['amount'],
      type: map['type'],
      date: DateTime.parse(map['date']),
      description: map['description'] ?? '',
    );
  }
}
