import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

/// Model for Emergency Contact
class EmergencyContact {
  final String id;
  final String name;
  final String number;
  final String type; // Police, Fire, Ambulance, MDRRMO, etc.
  final String description;

  EmergencyContact({
    required this.id,
    required this.name,
    required this.number,
    required this.type,
    this.description = '',
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'number': number,
        'type': type,
        'description': description,
      };

  factory EmergencyContact.fromJson(Map<String, dynamic> json) =>
      EmergencyContact(
        id: json['id'],
        name: json['name'],
        number: json['number'],
        type: json['type'],
        description: json['description'] ?? '',
      );

  EmergencyContact copyWith({
    String? id,
    String? name,
    String? number,
    String? type,
    String? description,
  }) {
    return EmergencyContact(
      id: id ?? this.id,
      name: name ?? this.name,
      number: number ?? this.number,
      type: type ?? this.type,
      description: description ?? this.description,
    );
  }
}

/// Service for managing emergency contacts
/// Shared between MDRRMO (edit) and Residents (view-only)
class EmergencyContactsService {
  static const String _storageKey = 'emergency_contacts';

  // Default emergency contacts (loaded on first run)
  static final List<EmergencyContact> _defaultContacts = [
    EmergencyContact(
      id: '1',
      name: 'Bulan MDRRMO',
      number: '0917-123-4567',
      type: 'MDRRMO',
      description: 'Municipal Disaster Risk Reduction',
    ),
    EmergencyContact(
      id: '2',
      name: 'Police Station',
      number: '0918-234-5678',
      type: 'Police',
      description: 'Bulan Police Emergency',
    ),
    EmergencyContact(
      id: '3',
      name: 'Fire Department',
      number: '0919-345-6789',
      type: 'Fire',
      description: 'Bulan Fire Station',
    ),
    EmergencyContact(
      id: '4',
      name: 'Medical Emergency',
      number: '0920-456-7890',
      type: 'Medical',
      description: 'Bulan District Hospital',
    ),
    EmergencyContact(
      id: '5',
      name: 'Coast Guard',
      number: '0921-567-8901',
      type: 'Coast Guard',
      description: 'Philippine Coast Guard - Sorsogon',
    ),
    EmergencyContact(
      id: '6',
      name: 'Red Cross',
      number: '143',
      type: 'Medical',
      description: 'Philippine Red Cross',
    ),
    EmergencyContact(
      id: '7',
      name: 'National Emergency',
      number: '911',
      type: 'Emergency',
      description: 'National Emergency Hotline',
    ),
  ];

  /// Get all emergency contacts
  Future<List<EmergencyContact>> getAllContacts() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final String? contactsJson = prefs.getString(_storageKey);

      if (contactsJson == null) {
        // First run - save and return default contacts
        await _saveContacts(_defaultContacts);
        return _defaultContacts;
      }

      final List<dynamic> jsonList = json.decode(contactsJson);
      return jsonList.map((json) => EmergencyContact.fromJson(json)).toList();
    } catch (e) {
      print('Error loading contacts: $e');
      return _defaultContacts;
    }
  }

  /// Add new contact (MDRRMO only)
  Future<void> addContact(EmergencyContact contact) async {
    final contacts = await getAllContacts();
    contacts.add(contact);
    await _saveContacts(contacts);
  }

  /// Update existing contact (MDRRMO only)
  Future<void> updateContact(EmergencyContact contact) async {
    final contacts = await getAllContacts();
    final index = contacts.indexWhere((c) => c.id == contact.id);
    if (index != -1) {
      contacts[index] = contact;
      await _saveContacts(contacts);
    }
  }

  /// Delete contact (MDRRMO only)
  Future<void> deleteContact(String id) async {
    final contacts = await getAllContacts();
    contacts.removeWhere((c) => c.id == id);
    await _saveContacts(contacts);
  }

  /// Save contacts to local storage
  Future<void> _saveContacts(List<EmergencyContact> contacts) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final String contactsJson =
          json.encode(contacts.map((c) => c.toJson()).toList());
      await prefs.setString(_storageKey, contactsJson);
    } catch (e) {
      print('Error saving contacts: $e');
      throw Exception('Failed to save contacts');
    }
  }

  /// Get contact types for dropdown
  static List<String> getContactTypes() {
    return [
      'MDRRMO',
      'Police',
      'Fire',
      'Medical',
      'Coast Guard',
      'Emergency',
      'Other',
    ];
  }

  /// Generate unique ID
  String generateId() {
    return DateTime.now().millisecondsSinceEpoch.toString();
  }
}
