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
        textTheme: _buildResponsiveTextTheme(),
      ),
      home: PizzaOrderScreen(),
      debugShowCheckedModeBanner: false,
    );
  }

  TextTheme _buildResponsiveTextTheme() {
    return const TextTheme(
      displayLarge: TextStyle(fontSize: 32, fontWeight: FontWeight.bold),
      displayMedium: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
      displaySmall: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
      headlineLarge: TextStyle(fontSize: 22, fontWeight: FontWeight.w600),
      headlineMedium: TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
      headlineSmall: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
      titleLarge: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
      titleMedium: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
      titleSmall: TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
      bodyLarge: TextStyle(fontSize: 16),
      bodyMedium: TextStyle(fontSize: 14),
      bodySmall: TextStyle(fontSize: 12),
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
    _tabController = TabController(length: 3, vsync: this);
    
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

  // Método para calcular totales del historial
  Map<String, dynamic> _calculateHistoryTotals() {
    Map<String, int> totalPizzas = {};
    double totalCost = 0;
    double totalSuggested = 0;
    int totalOrders = orderHistory.length;

    // Inicializar contadores
    pizzaNames.keys.forEach((key) {
      totalPizzas[key] = 0;
    });

    // Sumar todas las pizzas del historial
    for (var order in orderHistory) {
      totalCost += order.total;
      totalSuggested += order.suggestedTotal;
      
      order.items.forEach((pizza, quantity) {
        totalPizzas[pizza] = (totalPizzas[pizza] ?? 0) + quantity;
      });
    }

    return {
      'pizzas': totalPizzas,
      'totalCost': totalCost,
      'totalSuggested': totalSuggested,
      'totalOrders': totalOrders,
    };
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

  // Función para obtener tamaños responsivos
  double _getResponsiveSize(BuildContext context, double baseSize) {
    final screenWidth = MediaQuery.of(context).size.width;
    final scaleFactor = screenWidth / 375; // 375 es el ancho base (iPhone)
    return baseSize * scaleFactor.clamp(0.8, 1.3); // Limitar el escalado
  }

  EdgeInsets _getResponsivePadding(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    if (screenWidth < 600) {
      return EdgeInsets.all(12);
    } else if (screenWidth < 900) {
      return EdgeInsets.all(16);
    } else {
      return EdgeInsets.all(20);
    }
  }

  @override
  Widget build(BuildContext context) {
    final responsiveTitleSize = _getResponsiveSize(context, 20);
    
    return Scaffold(
      backgroundColor: Color(0xFFf5f5f5),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 2,
        centerTitle: true,
        title: Text(
          'Pizzas Congeladas',
          style: TextStyle(
            fontSize: responsiveTitleSize,
            fontWeight: FontWeight.bold,
            color: Colors.black,
          ),
        ),
        bottom: TabBar(
          controller: _tabController,
          labelColor: Colors.black,
          unselectedLabelColor: Colors.grey[500],
          indicatorColor: Colors.black,
          indicatorWeight: 3,
          indicatorSize: TabBarIndicatorSize.label,
          labelStyle: TextStyle(
            fontSize: _getResponsiveSize(context, 15), 
            fontWeight: FontWeight.w600
          ),
          unselectedLabelStyle: TextStyle(
            fontSize: _getResponsiveSize(context, 14), 
            fontWeight: FontWeight.w400
          ),
          tabs: [
            Tab(
              icon: Icon(Icons.shopping_cart, size: _getResponsiveSize(context, 22)),
              text: 'Pedidos',
            ),
            Tab(
              icon: Icon(Icons.history, size: _getResponsiveSize(context, 22)),
              text: 'Historial',
            ),
            Tab(
              icon: Icon(Icons.analytics, size: _getResponsiveSize(context, 22)),
              text: 'Resumen',
            ),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildOrdersTab(context),
          _buildHistoryTab(context),
          _buildSummaryTab(context),
        ],
      ),
    );
  }

  Widget _buildOrdersTab(BuildContext context) {
    return SingleChildScrollView(
      padding: _getResponsivePadding(context),
      child: Column(
        children: [
          // Cliente Section
          _buildCard(
            context: context,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Cliente',
                  style: TextStyle(
                    fontSize: _getResponsiveSize(context, 16),
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
                SizedBox(height: 8),
                TextField(
                  controller: _clientNameController,
                  decoration: InputDecoration(
                    hintText: 'Nombre del cliente',
                    hintStyle: TextStyle(fontSize: _getResponsiveSize(context, 14)),
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
                  style: TextStyle(fontSize: _getResponsiveSize(context, 14)),
                ),
              ],
            ),
          ),
          
          SizedBox(height: 16),
          
          // BI Pizzas Section
          _buildCard(
            context: context,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Pizzas BI',
                  style: TextStyle(
                    fontSize: _getResponsiveSize(context, 16),
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
                SizedBox(height: 12),
                ..._buildPizzaItems(context, ['bi_americana', 'bi_hawaiana', 'bi_peperoni']),
              ],
            ),
          ),
          
          SizedBox(height: 16),
          
          // Personal Pizzas Section
          _buildCard(
            context: context,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Pizzas Personales',
                  style: TextStyle(
                    fontSize: _getResponsiveSize(context, 16),
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
                SizedBox(height: 12),
                ..._buildPizzaItems(context, ['personal_americana', 'personal_hawaiana', 'personal_peperoni']),
              ],
            ),
          ),
          
          SizedBox(height: 16),
          
          // Delivery Section
          _buildCard(
            context: context,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Entrega',
                  style: TextStyle(
                    fontSize: _getResponsiveSize(context, 16),
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
                SizedBox(height: 12),
                _buildDaySelector(context),
              ],
            ),
          ),
          
          SizedBox(height: 16),
          
          // Total Section
          _buildCard(
            context: context,
            child: Column(
              children: [
                Text(
                  'Total: S/${_calculateTotal().toStringAsFixed(2)}',
                  style: TextStyle(
                    fontSize: _getResponsiveSize(context, 24),
                    fontWeight: FontWeight.bold,
                    color: Colors.green[700],
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  'Precio sugerido: S/${_calculateSuggestedTotal().toStringAsFixed(2)}',
                  style: TextStyle(
                    fontSize: _getResponsiveSize(context, 14),
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
                  fontSize: _getResponsiveSize(context, 16),
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCard({required BuildContext context, required Widget child}) {
    return Container(
      width: double.infinity,
      padding: _getResponsivePadding(context),
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

  Widget _buildDaySelector(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final crossAxisCount = screenWidth < 600 ? 3 : screenWidth < 900 ? 4 : 7;
    
    return GridView.builder(
      shrinkWrap: true,
      physics: NeverScrollableScrollPhysics(),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: crossAxisCount,
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
        childAspectRatio: 2.5,
      ),
      itemCount: weekDays.length,
      itemBuilder: (context, index) {
        final day = weekDays[index];
        final isSelected = selectedDay == day;
        
        return GestureDetector(
          onTap: () => _selectDay(day),
          child: Container(
            decoration: BoxDecoration(
              color: isSelected ? Color(0xFF2f3d4c) : Colors.white,
              border: Border.all(
                color: isSelected ? Color(0xFF2f3d4c) : Colors.grey[300]!,
              ),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Center(
              child: Text(
                day,
                style: TextStyle(
                  color: isSelected ? Colors.white : Colors.black87,
                  fontSize: _getResponsiveSize(context, 12),
                  fontWeight: FontWeight.w500,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ),
        );
      },
    );
  }

  List<Widget> _buildPizzaItems(BuildContext context, List<String> pizzaKeys) {
    return pizzaKeys.map((pizzaKey) {
      final cost = pizzas[pizzaKey]?['cost'] ?? 0;
      final suggested = pizzas[pizzaKey]?['suggested'] ?? 0;
      final name = pizzaNames[pizzaKey] ?? '';

      return Container(
        margin: EdgeInsets.only(bottom: 16),
        padding: EdgeInsets.symmetric(vertical: 10, horizontal: 6),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Fila principal (nombre + cantidad)
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    name,
                    style: TextStyle(
                      fontSize: _getResponsiveSize(context, 16),
                      fontWeight: FontWeight.w600,
                      color: Colors.black87,
                    ),
                  ),
                ),
                Row(
                  children: [
                    _buildQuantityButton(context, Icons.remove, () => _updateQuantity(pizzaKey, -1)),
                    SizedBox(width: 14),
                    Container(
                      width: 30,
                      alignment: Alignment.center,
                      child: Text(
                        '${quantities[pizzaKey]}',
                        style: TextStyle(
                          fontSize: _getResponsiveSize(context, 16),
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    SizedBox(width: 14),
                    _buildQuantityButton(context, Icons.add, () => _updateQuantity(pizzaKey, 1)),
                  ],
                ),
              ],
            ),

            SizedBox(height: 8),

            // Fila de precios
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Costo: S/${cost.toStringAsFixed(2)}',
                  style: TextStyle(
                    fontSize: _getResponsiveSize(context, 13),
                    color: Colors.red,
                  ),
                ),
                Text(
                  'Precio sugerido: S/${suggested.toStringAsFixed(2)}',
                  style: TextStyle(
                    fontSize: _getResponsiveSize(context, 13),
                    fontWeight: FontWeight.w600,
                    color: Colors.green,
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

  Widget _buildQuantityButton(BuildContext context, IconData icon, VoidCallback onTap) {
    final buttonSize = _getResponsiveSize(context, 32);
    
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: buttonSize,
        height: buttonSize,
        decoration: BoxDecoration(
          color: Colors.grey[200],
          shape: BoxShape.circle,
        ),
        child: Icon(icon, size: _getResponsiveSize(context, 18), color: Colors.black87),
      ),
    );
  }

  Widget _buildHistoryTab(BuildContext context) {
    return Column(
      children: [
        Container(
          padding: _getResponsivePadding(context),
          child: Text(
            'Historial de Pedidos',
            style: TextStyle(
              fontSize: _getResponsiveSize(context, 18),
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
                      fontSize: _getResponsiveSize(context, 16),
                      color: Colors.grey[600],
                    ),
                  ),
                )
              : ListView.builder(
                  padding: _getResponsivePadding(context),
                  itemCount: orderHistory.length,
                  itemBuilder: (context, index) {
                    final reversedIndex = orderHistory.length - 1 - index;
                    return _buildOrderItem(context, reversedIndex);
                  },
                ),
        ),
        
        if (orderHistory.isNotEmpty)
          Padding(
            padding: _getResponsivePadding(context),
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
                    fontSize: _getResponsiveSize(context, 16),
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildSummaryTab(BuildContext context) {
    final historyTotals = _calculateHistoryTotals();
    
    return SingleChildScrollView(
      padding: _getResponsivePadding(context),
      child: Column(
        children: [
          // Header
          Container(
            width: double.infinity,
            padding: EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.indigo[400]!, Colors.indigo[600]!],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              children: [
                Icon(
                  Icons.analytics,
                  color: Colors.white,
                  size: _getResponsiveSize(context, 40),
                ),
                SizedBox(height: 8),
                Text(
                  'Resumen de Ventas',
                  style: TextStyle(
                    fontSize: _getResponsiveSize(context, 24),
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                Text(
                  'Estadísticas generales del negocio',
                  style: TextStyle(
                    fontSize: _getResponsiveSize(context, 14),
                    color: Colors.white70,
                  ),
                ),
              ],
            ),
          ),
          
          SizedBox(height: 20),
          
          if (orderHistory.isEmpty)
            Center(
              child: Column(
                children: [
                  SizedBox(height: 60),
                  Icon(
                    Icons.inbox_outlined,
                    size: _getResponsiveSize(context, 80),
                    color: Colors.grey[400],
                  ),
                  SizedBox(height: 16),
                  Text(
                    'No hay datos disponibles',
                    style: TextStyle(
                      fontSize: _getResponsiveSize(context, 18),
                      color: Colors.grey[600],
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'Realiza algunos pedidos para ver las estadísticas',
                    style: TextStyle(
                      fontSize: _getResponsiveSize(context, 14),
                      color: Colors.grey[500],
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            )
          else ...[
            // Resumen general
            _buildTotalSummaryCard(context, historyTotals),
            
            SizedBox(height: 20),
            
            // Totales por pizza
            _buildPizzaTotalsCard(context, historyTotals['pizzas']),
            
            SizedBox(height: 20),
            
            // Información adicional
            _buildAdditionalStats(context, historyTotals),
          ],
        ],
      ),
    );
  }

  Widget _buildAdditionalStats(BuildContext context, Map<String, dynamic> totals) {
    final avgOrderValue = totals['totalOrders'] > 0 
        ? totals['totalCost'] / totals['totalOrders'] 
        : 0.0;
    
    final avgSuggestedValue = totals['totalOrders'] > 0 
        ? totals['totalSuggested'] / totals['totalOrders'] 
        : 0.0;

    // Contar pizzas BI vs Personales
    int totalBI = 0;
    int totalPersonal = 0;
    
    (totals['pizzas'] as Map<String, int>).forEach((key, value) {
      if (key.contains('personal')) {
        totalPersonal += value;
      } else {
        totalBI += value;
      }
    });

    return Column(
      children: [
        // Promedios
        _buildCard(
          context: context,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.trending_up, color: Colors.orange[700], size: _getResponsiveSize(context, 20)),
                  SizedBox(width: 8),
                  Text(
                    'Promedios por Pedido',
                    style: TextStyle(
                      fontSize: _getResponsiveSize(context, 16),
                      fontWeight: FontWeight.bold,
                      color: Colors.orange[700],
                    ),
                  ),
                ],
              ),
              SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: _buildStatItem(
                      context,
                      'Valor Promedio (Costo)',
                      'S/ ${avgOrderValue.toStringAsFixed(2)}',
                      Colors.blue,
                    ),
                  ),
                  SizedBox(width: 16),
                  Expanded(
                    child: _buildStatItem(
                      context,
                      'Valor Promedio (Sugerido)',
                      'S/ ${avgSuggestedValue.toStringAsFixed(2)}',
                      Colors.green,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        
        SizedBox(height: 16),
        
        // Distribución BI vs Personal
        _buildCard(
          context: context,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.pie_chart, color: Colors.purple[700], size: _getResponsiveSize(context, 20)),
                  SizedBox(width: 8),
                  Text(
                    'Distribución de Ventas',
                    style: TextStyle(
                      fontSize: _getResponsiveSize(context, 16),
                      fontWeight: FontWeight.bold,
                      color: Colors.purple[700],
                    ),
                  ),
                ],
              ),
              SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: _buildStatItem(
                      context,
                      'Pizzas BI Vendidas',
                      '$totalBI unidades',
                      Colors.indigo,
                    ),
                  ),
                  SizedBox(width: 16),
                  Expanded(
                    child: _buildStatItem(
                      context,
                      'Pizzas Personales Vendidas',
                      '$totalPersonal unidades',
                      Colors.teal,
                    ),
                  ),
                ],
              ),
              SizedBox(height: 12),
              if (totalBI + totalPersonal > 0)
                Row(
                  children: [
                    Expanded(
                      child: LinearProgressIndicator(
                        value: totalBI / (totalBI + totalPersonal),
                        backgroundColor: Colors.teal[200],
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.indigo),
                        minHeight: 8,
                      ),
                    ),
                    SizedBox(width: 12),
                    Text(
                      '${((totalBI / (totalBI + totalPersonal)) * 100).toStringAsFixed(1)}% BI',
                      style: TextStyle(
                        fontSize: _getResponsiveSize(context, 12),
                        fontWeight: FontWeight.w600,
                        color: Colors.indigo,
                      ),
                    ),
                  ],
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildStatItem(BuildContext context, String label, String value, Color color) {
    return Container(
      padding: EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: _getResponsiveSize(context, 12),
              color: Colors.grey[600],
              fontWeight: FontWeight.w500,
            ),
          ),
          SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: _getResponsiveSize(context, 16),
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTotalSummaryCard(BuildContext context, Map<String, dynamic> totals) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.blue[50]!, Colors.blue[100]!],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.blue[200]!),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildSummaryItem(
                context,
                'Total Pedidos',
                '${totals['totalOrders']}',
                Icons.receipt,
                Colors.blue,
              ),
              _buildSummaryItem(
                context,
                'Costo Total',
                'S/ ${totals['totalCost'].toStringAsFixed(2)}',
                Icons.monetization_on,
                Colors.red,
              ),
            ],
          ),
          SizedBox(height: 12),
          _buildSummaryItem(
            context,
            'Precio Sugerido Total',
            'S/ ${totals['totalSuggested'].toStringAsFixed(2)}',
            Icons.trending_up,
            Colors.green,
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryItem(BuildContext context, String label, String value, IconData icon, Color color) {
    return Column(
      children: [
        Icon(icon, color: color, size: _getResponsiveSize(context, 24)),
        SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: _getResponsiveSize(context, 12),
            color: Colors.grey[600],
            fontWeight: FontWeight.w500,
          ),
        ),
        SizedBox(height: 2),
        Text(
          value,
          style: TextStyle(
            fontSize: _getResponsiveSize(context, 16),
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
      ],
    );
  }

  Widget _buildPizzaTotalsCard(BuildContext context, Map<String, int> pizzaTotals) {
    final activePizzas = pizzaTotals.entries
        .where((entry) => entry.value > 0)
        .toList();

    if (activePizzas.isEmpty) return SizedBox.shrink();

    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.green[50],
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.green[200]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.local_pizza, color: Colors.green[700], size: _getResponsiveSize(context, 20)),
              SizedBox(width: 8),
              Text(
                'Total de Pizzas Vendidas',
                style: TextStyle(
                  fontSize: _getResponsiveSize(context, 16),
                  fontWeight: FontWeight.bold,
                  color: Colors.green[700],
                ),
              ),
            ],
          ),
          SizedBox(height: 12),
          GridView.builder(
            shrinkWrap: true,
            physics: NeverScrollableScrollPhysics(),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: MediaQuery.of(context).size.width < 600 ? 1 : 2,
              crossAxisSpacing: 8,
              mainAxisSpacing: 8,
              childAspectRatio: 4,
            ),
            itemCount: activePizzas.length,
            itemBuilder: (context, index) {
              final entry = activePizzas[index];
              final pizzaName = pizzaNames[entry.key] ?? entry.key;
              
              return Container(
                padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: Colors.green[200]!),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        pizzaName,
                        style: TextStyle(
                          fontSize: _getResponsiveSize(context, 13),
                          fontWeight: FontWeight.w600,
                          color: Colors.black87,
                        ),
                      ),
                    ),
                    Container(
                      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.green[100],
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        '${entry.value}',
                        style: TextStyle(
                          fontSize: _getResponsiveSize(context, 12),
                          fontWeight: FontWeight.bold,
                          color: Colors.green[700],
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildOrderItem(BuildContext context, int index) {
    final order = orderHistory[index];

    // Calcular totales
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
        padding: _getResponsivePadding(context),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Fecha y Total
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  order.date.substring(0, 16),
                  style: TextStyle(
                    fontSize: _getResponsiveSize(context, 12), 
                    color: Colors.grey[600]
                  ),
                ),
                Text(
                  'S/ ${order.total.toStringAsFixed(2)}',
                  style: TextStyle(
                    fontSize: _getResponsiveSize(context, 15),
                    fontWeight: FontWeight.bold,
                    color: Colors.green[700],
                  ),
                ),
              ],
            ),
            SizedBox(height: 8),

            // Cliente
            Text(
              "Cliente: ${order.clientName}",
              style: TextStyle(
                fontSize: _getResponsiveSize(context, 14),
                fontWeight: FontWeight.w600,
                color: Colors.black87,
              ),
            ),
            SizedBox(height: 4),

            // Entrega
            Text(
              "Entrega: ${order.deliveryDay}",
              style: TextStyle(
                fontSize: _getResponsiveSize(context, 13), 
                color: Colors.black87
              ),
            ),
            SizedBox(height: 10),

            // Lista de productos
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: order.items.entries
                  .where((entry) => entry.value > 0)
                  .map((entry) {
                final pizzaName = pizzaNames[entry.key] ?? entry.key;
                return Padding(
                  padding: EdgeInsets.only(bottom: 2),
                  child: Text(
                    "• $pizzaName: ${entry.value} unid.",
                    style: TextStyle(
                      fontSize: _getResponsiveSize(context, 13), 
                      color: Colors.black87
                    ),
                  ),
                );
              }).toList(),
            ),
            Divider(height: 18),

            // Resumen Totales
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  "Total BI Pizzas: $totalPizzas",
                  style: TextStyle(
                    fontSize: _getResponsiveSize(context, 13), 
                    fontWeight: FontWeight.w500
                  )
                ),
                Text(
                  "Total Personales: $totalPersonales",
                  style: TextStyle(
                    fontSize: _getResponsiveSize(context, 13), 
                    fontWeight: FontWeight.w500
                  )
                ),
              ],
            ),
            SizedBox(height: 6),

            // Precio sugerido
            Text(
              "Precio sugerido: S/ ${order.suggestedTotal.toStringAsFixed(2)}",
              style: TextStyle(
                fontSize: _getResponsiveSize(context, 13),
                fontWeight: FontWeight.w600,
                color: Colors.deepOrange,
              ),
            ),
            SizedBox(height: 12),

            // Botones
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => _editOrder(index),
                    style: OutlinedButton.styleFrom(
                      padding: EdgeInsets.symmetric(vertical: 10),
                    ),
                    child: Text(
                      "Editar",
                      style: TextStyle(
                        fontSize: _getResponsiveSize(context, 13), 
                        fontWeight: FontWeight.w600
                      )
                    ),
                  ),
                ),
                SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => _deleteOrder(index),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      foregroundColor: Colors.white,
                      padding: EdgeInsets.symmetric(vertical: 10),
                    ),
                    child: Text(
                      "Eliminar",
                      style: TextStyle(
                        fontSize: _getResponsiveSize(context, 13), 
                        fontWeight: FontWeight.w600
                      )
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