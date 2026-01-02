import '../bluetooth/g1_manager.dart';
import '../models/note_model.dart';

/// G1 Notes feature for managing quick notes on the dashboard.
class G1Notes {
  final G1Manager _manager;

  G1Notes(this._manager);

  /// Add or update a quick note.
  ///
  /// [noteNumber] - Position 1-4
  /// [name] - Note title
  /// [text] - Note content
  Future<void> add({
    required int noteNumber,
    required String name,
    required String text,
  }) async {
    if (!_manager.isConnected) {
      throw StateError('Not connected to glasses');
    }

    final note = G1NoteModel(
      noteNumber: noteNumber,
      name: name,
      text: text,
    );

    await _manager.sendCommand(note.buildAddCommand());
  }

  /// Add a note using a model.
  Future<void> addNote(G1NoteModel note) async {
    if (!_manager.isConnected) {
      throw StateError('Not connected to glasses');
    }

    await _manager.sendCommand(note.buildAddCommand());
  }

  /// Delete a quick note.
  ///
  /// [noteNumber] - Position 1-4
  Future<void> delete(int noteNumber) async {
    if (!_manager.isConnected) {
      throw StateError('Not connected to glasses');
    }

    final note = G1NoteModel(
      noteNumber: noteNumber,
      name: '',
      text: '',
    );

    await _manager.sendCommand(note.buildDeleteCommand());
  }

  /// Update multiple notes at once.
  ///
  /// Fills remaining slots (up to 4) with empty notes to clear old content.
  Future<void> updateAll(List<G1NoteModel> notes) async {
    if (!_manager.isConnected) {
      throw StateError('Not connected to glasses');
    }

    // Send all provided notes
    for (final note in notes) {
      await addNote(note);
    }

    // Clear remaining slots if less than 4 notes provided
    if (notes.length < 4) {
      for (int i = notes.length; i < 4; i++) {
        await delete(i + 1);
      }
    }
  }
}
