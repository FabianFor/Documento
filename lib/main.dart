import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

void main() {
  runApp(PizzaOrderApp());
}

class PizzaOrderApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Pizzas Congeladas',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        visualDensity: VisualDensity.adaptivePlatformDensity,
      ),
      home: PizzaOrderScreen(),
      debugShowCheckedModeBanner: false,
    );
  }
}

class PizzaOrder {
  final String date;
  final String clientName;
  final String deliveryDay;
  final Map<String, int> items;
  final double total;
  final double suggestedTotal;

  PizzaOrder({
    required this.date,
    required this.clientName,
    required this.deliveryDay,
    required this.items,
    required this.total,
    required this.suggestedTotal,
  });

  Map<String, dynamic> toJson() {
    return {
      'date': date,
      'clientName': clientName,
      'deliveryDay': deliveryDay,
      'items': items,
      'total': total,
      'suggestedTotal': suggestedTotal,
    };
  }

  factory PizzaOrder.fromJson(Map<String, dynamic> json) {
    return PizzaOrder(
      date: json['date'],
      clientName: json['clientName'],
      deliveryDay: json['deliveryDay'],
      items: Map<String, int>.from(json['items']),
      total: json['total'].toDouble(),
      suggestedTotal: json['suggestedTotal'].toDouble(),
    );
  }
}

class PizzaOrderScreen extends StatefulWidget {
  @override
  _PizzaOrderScreenState createState() => _PizzaOrderScreenState();
}

class _PizzaOrderScreenState extends State<PizzaOrderScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  
  // Controllers
  final TextEditingController _clientNameController = TextEditingController();

  // Pizza data
  final Map<String, Map<String, double>> pizzas = {
    'bi_americana': {'cost': 10.50, 'suggested': 15.00},
    'bi_hawaiana': {'cost': 11.00, 'suggested': 15.50},
    'bi_peperoni': {'cost': 11.50, 'suggested': 16.00},
    'personal_americana': {'cost': 6.00, 'suggested': 9.00},
    'personal_hawaiana': {'cost': 6.50, 'suggested': 9.50},
    'personal_peperoni': {'cost': 7.00, 'suggested': 10.50},
  };

  final Map<String, String> pizzaNames = {
    'bi_americana': 'BI Americana',
    'bi_hawaiana': 'BI Hawaiana',
    'bi_peperoni': 'BI Peperoni',
    'personal_americana': 'Personal Americana',
    'personal_hawaiana': 'Personal Hawaiana',
    'personal_peperoni': 'Personal Peperoni',
  };

  // State variables
  Map<String, int> quantities = {};
  String selectedDay = '';
  List<PizzaOrder> orderHistory = [];
  int editingOrderIndex = -1;

  final List<String> weekDays = [
    'Lunes', 'Martes', 'Miércoles', 'Jueves', 'Viernes', 'Sábado', 'Domingo'
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    
    // Initialize quantities
    pizzas.keys.forEach((pizza) {
      quantities[pizza] = 0;
    });
    
    _loadHistory();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _clientNameController.dispose();
    super.dispose();
  }

  // Storage methods
  Future<void> _saveHistory() async {
    final prefs = await SharedPreferences.getInstance();
    final List<String> historyJson = orderHistory
        .map((order) => json.encode(order.toJson()))
        .toList();
    await prefs.setStringList('pizza_orders', historyJson);
  }

  Future<void> _loadHistory() async {
    final prefs = await SharedPreferences.getInstance();
    final List<String>? historyJson = prefs.getStringList('pizza_orders');
    
    if (historyJson != null) {
      setState(() {
        orderHistory = historyJson
            .map((orderStr) => PizzaOrder.fromJson(json.decode(orderStr)))
            .toList();
      });
    }
  }

  // Calculation methods
  double _calculateTotal() {
    double total = 0;
    quantities.forEach((pizza, qty) {
      total += qty * (pizzas[pizza]?['cost'] ?? 0);
    });
    return total;
  }

  double _calculateSuggestedTotal() {
    double total = 0;
    quantities.forEach((pizza, qty) {
      total += qty * (pizzas[pizza]?['suggested'] ?? 0);
    });
    return total;
  }

  // UI methods
  void _updateQuantity(String pizza, int change) {
    setState(() {
      quantities[pizza] = (quantities[pizza]! + change).clamp(0, 999);
    });
  }

  void _selectDay(String day) {
    setState(() {
      selectedDay = day;
    });
  }

  void _clearOrder() {
    setState(() {
      quantities.forEach((pizza, qty) {
        quantities[pizza] = 0;
      });
      selectedDay = '';
      editingOrderIndex = -1;
      _clientNameController.clear();
    });
  }

  // Order management
  Future<void> _saveOrder() async {
    // Validations
    if (!quantities.values.any((qty) => qty > 0)) {
      _showAlert('⚠️ Selecciona al menos una pizza');
      return;
    }
    
    if (selectedDay.isEmpty) {
      _showAlert('⚠️ Selecciona un día de entrega');
      return;
    }
    
    if (_clientNameController.text.trim().isEmpty) {
      _showAlert('⚠️ Ingresa el nombre del cliente');
      return;
    }

    final order = PizzaOrder(
      date: DateTime.now().toString().substring(0, 19),
      clientName: _clientNameController.text.trim(),
      deliveryDay: selectedDay,
      items: Map<String, int>.from(quantities),
      total: _calculateTotal(),
      suggestedTotal: _calculateSuggestedTotal(),
    );

    setState(() {
      if (editingOrderIndex >= 0) {
        orderHistory[editingOrderIndex] = order;
      } else {
        orderHistory.add(order);
      }
    });

    await _saveHistory();
    _clearOrder();
    
    final message = editingOrderIndex >= 0 
        ? '✅ Pedido actualizado correctamente'
        : '✅ Pedido guardado correctamente';
    _showAlert(message);
  }

  void _editOrder(int index) {
    final order = orderHistory[index];
    
    setState(() {
      // Load order data
      quantities = Map<String, int>.from(order.items);
      selectedDay = order.deliveryDay;
      _clientNameController.text = order.clientName;
      editingOrderIndex = index;
    });
    
    // Switch to orders tab
    _tabController.animateTo(0);
  }

  Future<void> _deleteOrder(int index) async {
    final confirmed = await _showConfirmDialog(
      '¿Eliminar el pedido de ${orderHistory[index].clientName}?'
    );
    
    if (confirmed) {
      setState(() {
        orderHistory.removeAt(index);
      });
      await _saveHistory();
      _showAlert('✅ Pedido eliminado');
    }
  }

  Future<void> _clearHistory() async {
    final confirmed = await _showConfirmDialog(
      '¿Estás seguro de borrar todo el historial?'
    );
    
    if (confirmed) {
      setState(() {
        orderHistory.clear();
      });
      await _saveHistory();
      _showAlert('✅ Historial borrado');
    }
  }

  // UI Helper methods
  void _showAlert(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green,
        duration: Duration(seconds: 2),
      ),
    );
  }

  Future<bool> _showConfirmDialog(String message) async {
    return await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('⚠️ Confirmar Acción'),
          content: Text(message),
          actions: [
            TextButton(
              child: Text('Cancelar'),
              onPressed: () => Navigator.of(context).pop(false),
            ),
            TextButton(
              child: Text('Confirmar', style: TextStyle(color: Colors.red)),
              onPressed: () => Navigator.of(context).pop(true),
            ),
          ],
        );
      },
    ) ?? false;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Color(0xFFf5f5f5),
appBar: AppBar(
  backgroundColor: Colors.white,
  elevation: 2,
  centerTitle: true,
  title: Text(
    'Pizzas Congeladas',
    style: TextStyle(
      fontSize: 20,
      fontWeight: FontWeight.bold,
      color: const Color.fromARGB(255, 0, 0, 0),
    ),
  ),
  bottom: TabBar(
    controller: _tabController,
    labelColor: const Color.fromARGB(255, 0, 0, 0),
    unselectedLabelColor: Colors.grey[500],
    indicatorColor: const Color.fromARGB(255, 0, 0, 0),
    indicatorWeight: 3,
    indicatorSize: TabBarIndicatorSize.label,
    labelStyle: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
    unselectedLabelStyle: TextStyle(fontSize: 14, fontWeight: FontWeight.w400),
    tabs: [
      Tab(
        icon: Icon(Icons.shopping_cart, size: 22),
        text: 'Pedidos',
      ),
      Tab(
        icon: Icon(Icons.history, size: 22),
        text: 'Historial',
      ),
    ],
  ),
),

      body: TabBarView(
        controller: _tabController,
        children: [
          _buildOrdersTab(),
          _buildHistoryTab(),
        ],
      ),
    );
  }

  Widget _buildOrdersTab() {
    return SingleChildScrollView(
      padding: EdgeInsets.all(16),
      child: Column(
        children: [
          // Cliente Section
          _buildCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Cliente',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
                SizedBox(height: 8),
                TextField(
                  controller: _clientNameController,
                  decoration: InputDecoration(
                    hintText: 'Nombre del cliente',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(6),
                      borderSide: BorderSide(color: Colors.grey[300]!),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(6),
                      borderSide: BorderSide(color: Colors.grey[300]!),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(6),
                      borderSide: BorderSide(color: Colors.blue),
                    ),
                    contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  ),
                ),
              ],
            ),
          ),
          
          SizedBox(height: 16),
          
          // BI Pizzas Section
          _buildCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Pizzas BI',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
                SizedBox(height: 12),
                ..._buildPizzaItems(['bi_americana', 'bi_hawaiana', 'bi_peperoni']),
              ],
            ),
          ),
          
          SizedBox(height: 16),
          
          // Personal Pizzas Section
          _buildCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Pizzas Personales',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
                SizedBox(height: 12),
                ..._buildPizzaItems(['personal_americana', 'personal_hawaiana', 'personal_peperoni']),
              ],
            ),
          ),
          
          SizedBox(height: 16),
          
          // Delivery Section
          _buildCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Entrega',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
                SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: weekDays.map((day) {
                    final isSelected = selectedDay == day;
                    return GestureDetector(
                      onTap: () => _selectDay(day),
                      child: Container(
                        padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: isSelected ? Color(0xFF2f3d4c) : Colors.white,
                          border: Border.all(
                            color: isSelected ? Color(0xFF2f3d4c) : Colors.grey[300]!,
                          ),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          day,
                          style: TextStyle(
                            color: isSelected ? Colors.white : Colors.black87,
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ],
            ),
          ),
          
          SizedBox(height: 16),
          
          // Total Section
          _buildCard(
            child: Column(
              children: [
                Text(
                  'Total: S/${_calculateTotal().toStringAsFixed(2)}',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.green[700],
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  'Precio sugerido: S/${_calculateSuggestedTotal().toStringAsFixed(2)}',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
          ),
          
          SizedBox(height: 16),
          
          // Action Button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _saveOrder,
              style: ElevatedButton.styleFrom(
                backgroundColor: Color(0xFF2f3d4c),
                foregroundColor: Colors.white,
                padding: EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(6),
                ),
              ),
              child: Text(
                'Guardar Pedido',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCard({required Widget child}) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            spreadRadius: 0,
            blurRadius: 4,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: child,
    );
  }

List<Widget> _buildPizzaItems(List<String> pizzaKeys) {
  return pizzaKeys.map((pizzaKey) {
    final cost = pizzas[pizzaKey]?['cost'] ?? 0;
    final suggested = pizzas[pizzaKey]?['suggested'] ?? 0;
    final name = pizzaNames[pizzaKey] ?? '';

    return Container(
      margin: EdgeInsets.only(bottom: 16), // 🔹 más espacio entre ítems
      padding: EdgeInsets.symmetric(vertical: 10, horizontal: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 🔹 Fila principal (nombre + cantidad)
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  name,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.black87,
                  ),
                ),
              ),
              Row(
                children: [
                  _buildQuantityButton(Icons.remove, () => _updateQuantity(pizzaKey, -1)),
                  SizedBox(width: 14),
                  Container(
                    width: 30,
                    alignment: Alignment.center,
                    child: Text(
                      '${quantities[pizzaKey]}',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  SizedBox(width: 14),
                  _buildQuantityButton(Icons.add, () => _updateQuantity(pizzaKey, 1)),
                ],
              ),
            ],
          ),

          SizedBox(height: 8), // 🔹 más aire entre nombre y precios

          // 🔹 Fila de precios
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Costo: S/${cost.toStringAsFixed(2)}',
                style: TextStyle(
                  fontSize: 13,
                  color: const Color.fromARGB(255, 255, 0, 0),
                ),
              ),
              Text(
                'Precio sugerido: S/${suggested.toStringAsFixed(2)}',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: const Color.fromARGB(255, 26, 145, 26),
                ),
              ),
            ],
          ),
          SizedBox(height: 12),
          Divider(height: 1, color: Colors.grey[300]),
        ],
      ),
    );
  }).toList();
}


// Botón de + y -
Widget _buildQuantityButton(IconData icon, VoidCallback onTap) {
  return GestureDetector(
    onTap: onTap,
    child: Container(
      width: 32,
      height: 32,
      decoration: BoxDecoration(
        color: Colors.grey[200],
        shape: BoxShape.circle,
      ),
      child: Icon(icon, size: 18, color: Colors.black87),
    ),
  );
}


  Widget _buildHistoryTab() {
    return Column(
      children: [
        Container(
          padding: EdgeInsets.all(16),
          child: Text(
            'Historial de Pedidos',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
        ),
        Expanded(
          child: orderHistory.isEmpty
              ? Center(
                  child: Text(
                    'No hay pedidos guardados',
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.grey[600],
                    ),
                  ),
                )
              : ListView.builder(
                  padding: EdgeInsets.all(16),
                  itemCount: orderHistory.length,
                  itemBuilder: (context, index) {
                    final reversedIndex = orderHistory.length - 1 - index;
                    return _buildOrderItem(reversedIndex);
                  },
                ),
        ),
        if (orderHistory.isNotEmpty)
          Padding(
            padding: EdgeInsets.all(16),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _clearHistory,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  foregroundColor: Colors.white,
                  padding: EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(6),
                  ),
                ),
                child: Text(
                  'Borrar Historial',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }

Widget _buildOrderItem(int index) {
  final order = orderHistory[index];

  // 🔹 Calcular totales
  int totalPizzas = 0;
  int totalPersonales = 0;

  order.items.forEach((key, value) {
    if (key.toLowerCase().contains("personal")) {
      totalPersonales += value;
    } else {
      totalPizzas += value;
    }
  });

  return Card(
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
    elevation: 2,
    margin: EdgeInsets.only(bottom: 12),
    child: Padding(
      padding: EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 🔹 Fecha y Total
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                order.date.substring(0, 16),
                style: TextStyle(fontSize: 12, color: Colors.grey[600]),
              ),
              Text(
                'S/ ${order.total.toStringAsFixed(2)}',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: Colors.green[700],
                ),
              ),
            ],
          ),
          SizedBox(height: 8),

          // 🔹 Cliente
          Text(
            "Cliente: ${order.clientName}",
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Colors.black87,
            ),
          ),
          SizedBox(height: 4),

          // 🔹 Entrega
          Text(
            "Entrega: ${order.deliveryDay}",
            style: TextStyle(fontSize: 13, color: Colors.black87),
          ),
          SizedBox(height: 10),

          // 🔹 Lista de productos
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: order.items.entries
                .where((entry) => entry.value > 0)
                .map((entry) {
              final pizzaName = pizzaNames[entry.key] ?? entry.key;
              return Text(
                "• $pizzaName: ${entry.value} unid.",
                style: TextStyle(fontSize: 13, color: Colors.black87),
              );
            }).toList(),
          ),
          Divider(height: 18),

          // 🔹 Resumen Totales
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text("Total BI Pizzas: $totalPizzas",
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
              Text("Total Personales: $totalPersonales",
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
            ],
          ),
          SizedBox(height: 6),

          // 🔹 Precio sugerido
          Text(
            "Precio sugerido: S/ ${order.suggestedTotal.toStringAsFixed(2)}",
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: Colors.deepOrange,
            ),
          ),
          SizedBox(height: 12),

          // 🔹 Botones
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => _editOrder(index),
                  style: OutlinedButton.styleFrom(
                    padding: EdgeInsets.symmetric(vertical: 10),
                  ),
                  child: Text("Editar",
                      style: TextStyle(
                          fontSize: 13, fontWeight: FontWeight.w600)),
                ),
              ),
              SizedBox(width: 10),
              Expanded(
                child: ElevatedButton(
                  onPressed: () => _deleteOrder(index),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color.fromARGB(255, 255, 17, 0),
                    foregroundColor: Colors.white,
                    padding: EdgeInsets.symmetric(vertical: 10),
                  ),
                  child: Text("Eliminar",
                      style: TextStyle(
                          fontSize: 13, fontWeight: FontWeight.w600)),
                ),
              ),
            ],
          ),
        ],
      ),
    ),
  );
}
}