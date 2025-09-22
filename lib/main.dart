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
  final String deliveryMonth;
  final Map<String, int> items;
  final double total;
  final double suggestedTotal;

  PizzaOrder({
    required this.date,
    required this.clientName,
    required this.deliveryDay,
    required this.deliveryMonth,
    required this.items,
    required this.total,
    required this.suggestedTotal,
  });

  Map<String, dynamic> toJson() {
    return {
      'date': date,
      'clientName': clientName,
      'deliveryDay': deliveryDay,
      'deliveryMonth': deliveryMonth,
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
      deliveryMonth: json['deliveryMonth'],
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
  final TextEditingController _monthController = TextEditingController();

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
    _monthController.dispose();
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
      _monthController.clear();
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
    
    if (_monthController.text.trim().isEmpty) {
      _showAlert('⚠️ Ingresa el mes de entrega');
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
      deliveryMonth: _monthController.text.trim(),
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
      _monthController.text = order.deliveryMonth;
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
      appBar: AppBar(
        title: Column(
          children: [
            Text('🍕 Pizzas Congeladas', style: TextStyle(fontSize: 18)),
            Text('Sistema de Pedidos', style: TextStyle(fontSize: 12)),
          ],
        ),
        centerTitle: true,
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFFff6b6b), Color(0xFFee5a24)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
        bottom: TabBar(
          controller: _tabController,
          tabs: [
            Tab(text: 'Pedidos', icon: Icon(Icons.shopping_cart)),
            Tab(text: 'Historial', icon: Icon(Icons.history)),
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
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF667eea), Color(0xFF764ba2)],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
      ),
      child: SingleChildScrollView(
        padding: EdgeInsets.all(16),
        child: Column(
          children: [
            // Cliente Section
            _buildClientSection(),
            SizedBox(height: 16),
            
            // BI Pizzas Section
            _buildPizzaSection(
              title: '🍕 BI PERSONALES',
              pizzaKeys: ['bi_americana', 'bi_hawaiana', 'bi_peperoni'],
            ),
            SizedBox(height: 16),
            
            // Personal Pizzas Section
            _buildPizzaSection(
              title: '🍕 PERSONALES',
              pizzaKeys: ['personal_americana', 'personal_hawaiana', 'personal_peperoni'],
            ),
            SizedBox(height: 16),
            
            // Delivery Section
            _buildDeliverySection(),
            SizedBox(height: 16),
            
            // Total Section
            _buildTotalSection(),
            SizedBox(height: 16),
            
            // Action Buttons
            _buildActionButtons(),
          ],
        ),
      ),
    );
  }

  Widget _buildClientSection() {
    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Color(0xFFe3f2fd),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '👤 Nombre del Cliente',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Color(0xFF1976d2),
            ),
          ),
          SizedBox(height: 8),
          TextField(
            controller: _clientNameController,
            decoration: InputDecoration(
              hintText: 'Ingresa el nombre del cliente',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(5),
                borderSide: BorderSide(color: Color(0xFF1976d2), width: 2),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(5),
                borderSide: BorderSide(color: Color(0xFF1976d2), width: 2),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPizzaSection({required String title, required List<String> pizzaKeys}) {
    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Color(0xFFf8f9fa),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          SizedBox(height: 16),
          ...pizzaKeys.map((pizzaKey) => _buildPizzaItem(pizzaKey)).toList(),
        ],
      ),
    );
  }

  Widget _buildPizzaItem(String pizzaKey) {
    final cost = pizzas[pizzaKey]?['cost'] ?? 0;
    final suggested = pizzas[pizzaKey]?['suggested'] ?? 0;
    final name = pizzaNames[pizzaKey] ?? '';
    
    return Container(
      margin: EdgeInsets.only(bottom: 12),
      padding: EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.2),
            spreadRadius: 1,
            blurRadius: 5,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  'Costo: S/ ${cost.toStringAsFixed(2)} | Precio sugerido: S/ ${suggested.toStringAsFixed(2)}',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
          ),
          Row(
            children: [
              Container(
                decoration: BoxDecoration(
                  color: Colors.blue,
                  shape: BoxShape.circle,
                ),
                child: IconButton(
                  icon: Icon(Icons.remove, color: Colors.white, size: 20),
                  onPressed: () => _updateQuantity(pizzaKey, -1),
                ),
              ),
              SizedBox(width: 12),
              Container(
                width: 40,
                child: Text(
                  '${quantities[pizzaKey]}',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
              SizedBox(width: 12),
              Container(
                decoration: BoxDecoration(
                  color: Colors.blue,
                  shape: BoxShape.circle,
                ),
                child: IconButton(
                  icon: Icon(Icons.add, color: Colors.white, size: 20),
                  onPressed: () => _updateQuantity(pizzaKey, 1),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDeliverySection() {
    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Color(0xFFe3f2fd),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '📅 Día de Entrega',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Color(0xFF1976d2),
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
                  padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: isSelected ? Color(0xFF1976d2) : Colors.white,
                    border: Border.all(color: Color(0xFF1976d2), width: 2),
                    borderRadius: BorderRadius.circular(5),
                  ),
                  child: Text(
                    day,
                    style: TextStyle(
                      color: isSelected ? Colors.white : Color(0xFF1976d2),
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
          SizedBox(height: 12),
          TextField(
            controller: _monthController,
            decoration: InputDecoration(
              hintText: 'Mes (ej: Enero, Febrero...)',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(5),
                borderSide: BorderSide(color: Color(0xFF1976d2), width: 2),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(5),
                borderSide: BorderSide(color: Color(0xFF1976d2), width: 2),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTotalSection() {
    final total = _calculateTotal();
    final suggestedTotal = _calculateSuggestedTotal();
    
    return Container(
      padding: EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Color(0xFF28a745),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        children: [
          Text(
            '💰 TOTAL DEL PEDIDO',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          SizedBox(height: 8),
          Text(
            'S/ ${total.toStringAsFixed(2)}',
            style: TextStyle(
              fontSize: 32,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          SizedBox(height: 4),
          Text(
            'Precio sugerido: S/ ${suggestedTotal.toStringAsFixed(2)}',
            style: TextStyle(
              fontSize: 14,
              color: Colors.white.withOpacity(0.9),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtons() {
    return Column(
      children: [
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: _saveOrder,
            style: ElevatedButton.styleFrom(
              backgroundColor: Color(0xFF28a745),
              padding: EdgeInsets.symmetric(vertical: 16),
            ),
            child: Text(
              editingOrderIndex >= 0 ? '💾 Actualizar Pedido' : '💾 Guardar Pedido',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ),
        ),
        SizedBox(height: 8),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: _clearOrder,
            style: ElevatedButton.styleFrom(
              backgroundColor: Color(0xFFdc3545),
              padding: EdgeInsets.symmetric(vertical: 16),
            ),
            child: Text(
              '🗑️ Limpiar Todo',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildHistoryTab() {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF667eea), Color(0xFF764ba2)],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
      ),
      child: Column(
        children: [
          Container(
            padding: EdgeInsets.all(16),
            child: Text(
              '📋 Historial de Pedidos',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.white,
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
                        color: Colors.white70,
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
                    backgroundColor: Color(0xFFdc3545),
                    padding: EdgeInsets.symmetric(vertical: 16),
                  ),
                  child: Text(
                    '🗑️ Borrar Historial',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildOrderItem(int index) {
    final order = orderHistory[index];
    
    return Container(
      margin: EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Color(0xFFf8f9fa),
        borderRadius: BorderRadius.circular(8),
        border: Border(
          left: BorderSide(color: Colors.blue, width: 5),
        ),
      ),
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  order.date.substring(0, 16),
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                  ),
                ),
                Text(
                  'S/ ${order.total.toStringAsFixed(2)}',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF28a745),
                  ),
                ),
              ],
            ),
            SizedBox(height: 8),
            Text(
              '👤 Cliente: ${order.clientName}',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: Colors.blue,
              ),
            ),
            SizedBox(height: 4),
            Text(
              '📅 Entrega: ${order.deliveryDay} de ${order.deliveryMonth}',
              style: TextStyle(fontSize: 12, color: Colors.black87),
            ),
            SizedBox(height: 8),
            ...order.items.entries
                .where((entry) => entry.value > 0)
                .map((entry) {
              final pizzaName = pizzaNames[entry.key] ?? entry.key;
              return Text(
                '$pizzaName: ${entry.value} unidades',
                style: TextStyle(fontSize: 12, color: Colors.black87),
              );
            }).toList(),
            SizedBox(height: 4),
            Text(
              'Precio sugerido: S/ ${order.suggestedTotal.toStringAsFixed(2)}',
              style: TextStyle(
                fontSize: 11,
                color: Colors.grey[600],
              ),
            ),
            SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => _editOrder(index),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Color(0xFF17a2b8),
                      padding: EdgeInsets.symmetric(vertical: 8),
                    ),
                    child: Text(
                      '✏️ Editar',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
                SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => _deleteOrder(index),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Color(0xFFdc3545),
                      padding: EdgeInsets.symmetric(vertical: 8),
                    ),
                    child: Text(
                      '🗑️ Eliminar',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                    ),
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