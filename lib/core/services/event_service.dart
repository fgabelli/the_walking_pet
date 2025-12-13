import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../shared/models/event_model.dart';

final eventServiceProvider = Provider<EventService>((ref) {
  return EventService();
});

class EventService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  CollectionReference get _eventsRef => _firestore.collection('events');

  // Create a new event
  Future<void> createEvent(EventModel event) async {
    // Ensure date is in the future
    if (event.date.isBefore(DateTime.now())) {
      throw Exception('La data dell\'evento deve essere nel futuro.');
    }
    await _eventsRef.add(event.toFirestore());
  }

  // Join an event
  Future<void> joinEvent(String eventId, String userId) async {
    await _eventsRef.doc(eventId).update({
      'attendees': FieldValue.arrayUnion([userId])
    });
  }

  // Leave an event
  Future<void> leaveEvent(String eventId, String userId) async {
    await _eventsRef.doc(eventId).update({
      'attendees': FieldValue.arrayRemove([userId])
    });
  }

  // Stream of upcoming events
  Stream<List<EventModel>> getUpcomingEventsStream() {
    return _eventsRef
        .where('date', isGreaterThan: Timestamp.now())
        .orderBy('date', descending: false)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs
          .map((doc) => EventModel.fromFirestore(doc))
          .toList();
    });
  }
  
  // Delete event (only creator)
  Future<void> deleteEvent(String eventId) async {
    await _eventsRef.doc(eventId).delete();
  }
}
