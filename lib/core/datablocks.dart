import 'dart:typed_data';
import 'package:mudkip_frontend/pokemon_manager.dart';

/// # `Class` Datablock
/// ## A class that represents a datablock from a Game.
/// Datablocks are used to store data in files. Datablocks should be used in combination with other Datablocks to create a file handle.
/// For example, a save file will requires one block for the general data, one for the trainer, and one for each Pokémon.
sealed class Datablock {
  FileHandle fileHandle;
  int offset =
      0x00; // Offset of the datablock in the file. ALWAYS USE HEXADECIMAL INSTEAD OF DECIMAL, FOR CONSISTENCY.
  Datablock?
      parent; // The datablock that this datablock is relative to. In other words, it is the parent of the datablock.
  List<Datablock> children =
      []; // List of datablocks that are children of this datablock.
  List<dynamic> dataParsed =
      []; // List of data that has been parsed from only this datablock, not its children. For when creating the json structure.
  Datablock({required this.fileHandle}); // Constructor.

  /// # `int`combineBytesToInt8(`List<int> bytes`)
  /// ## A function that combines a single byte into a 8-bit integer.
  /// This function returns a 8-bit integer.
  int combineBytesToInt8(List<int> bytes) {
    ByteData byteData = ByteData.view(Uint8List.fromList(bytes).buffer);
    return byteData.getInt8(0);
  }

  /// # `int` combineBytesToInt16(`List<int> bytes`)
  /// ## A function that combines two bytes into a 16-bit integer.
  /// This function returns a 16-bit integer.
  int combineBytesToInt16(List<int> bytes) {
    ByteData byteData = ByteData.view(Uint8List.fromList(bytes).buffer);
    return byteData.getInt16(0, Endian.little);
  }

  /// # `int` combineBytesToInt32(`List<int> bytes`)
  /// ## A function that combines four bytes into a 32-bit integer.
  /// This function returns a 32-bit integer.
  int combineBytesToInt32(List<int> bytes) {
    ByteData byteData = ByteData.view(Uint8List.fromList(bytes).buffer);
    return byteData.getInt32(0, Endian.little);
  }

  int get8BitInt(int offset) {
    return combineBytesToInt8(getRange(offset, 1).toList());
  }

  int get16BitInt(int offset) {
    return combineBytesToInt16(getRange(offset, 2).toList());
  }

  int get32BitInt(int offset) {
    return combineBytesToInt32(getRange(offset, 4).toList());
  }

  /// # `Iterable<int>`getRange(`int offset`, `int length`)
  Iterable<int> getRange(int offset, int length) {
    return fileHandle.data.getRange(
        getAbsoluteOffset(offset), getAbsoluteOffset(offset) + length);
  }

  /// # `String`getString(`int offset`, `int length`)
  /// ## A function that gets a string from the datablock.
  /// This function returns a string.
  String getString(int offset, int length) {
    Iterable<int> string = getRange(offset, length);
    List<int> shortedString = [];
    int x = 0;
    while (x < string.length) {
      if (string.elementAt(x) == 0) {
        break;
      }
      shortedString.add(string.elementAt(x));
      x += 2;
    }
    String z = String.fromCharCodes(shortedString);
    z = z.replaceAll(String.fromCharCode(0x00), "");
    return z;
  }

  /// # `void` makeThisChildOf(`Datablock datablock`)
  /// ## A function that makes this datablock a child of the given datablock.
  void makeThisChildOf(Datablock datablock) {
    datablock.children.add(this);
    parent = datablock;
  }

  /// # `void` makeThisParentOf(`Datablock datablock`)
  /// ## A function that makes this datablock a parent of the given datablock.
  void makeThisParentOf(Datablock datablock) {
    datablock.offset += getAbsoluteOffset(0x00);
    children.add(datablock);
    datablock.parent = this;
  }

  /// # `int` getAbsoluteOffset(`int offset`)
  /// ## A function that returns the absolute offset of the relative offset.
  /// The absolute offset is the offset of the datablock relative to its parent datablocks.
  /// In other words, it is the offset of the datablock inside all of its parent datablocks.
  int getAbsoluteOffset(int relativeOffset) {
    Datablock? currentRelativeBlock = parent;
    List<Datablock> parentBlocks = [];
    while (currentRelativeBlock != null) {
      parentBlocks.add(currentRelativeBlock);
      currentRelativeBlock = currentRelativeBlock.parent;
    }
    int y = 0x00;
    for (Datablock datablock in parentBlocks) {
      y += datablock.offset;
    }
    return y + offset + relativeOffset;
  }

  /// # `Future<dynamic>` parse()
  /// ## A function that parses the datablock.
  /// This function returns a dynamic future.
  Future<dynamic> parse() async {
    // Override this in the child classes.
    return;
  }

  /// # `void` addDataToParsedList(`dynamic data`)
  /// ## A function that adds data to the parsed list.
  /// This function returns nothing.
  void addDataToParsedList(dynamic data) {
    dataParsed.add(data);
  }
}

/// # `Mixin` Gen3PokemonFormat
/// ## A mixin that contains the basic functions that are required by Generation 3 and beyond.
/// The modern format was introduced in Generation 3, and has been extended and expanded over each subsequent generation.
/// It is more cut down and compact than the old format, and requires bitmasks and more complex calculations to extract data.
/// Offsets are relative to the start of the block, so that it can be used in save files, as save files contain mutliple Pokémon and Trainers.
mixin Gen3PokemonFormat implements Datablock {
  String getNickname(int offset) {
    return getString(offset, 24);
  }

  /// # `Stats` getStats(`int offset`)
  /// ## A function that returns the stats of the Pokemon.
  Stats getEvStats(int offset) {
    Iterable<int> evRange = getRange(offset, 6);
    return Stats(
        hp: evRange.elementAt(0),
        attack: evRange.elementAt(1),
        defense: evRange.elementAt(2),
        specialAttack: evRange.elementAt(3),
        specialDefense: evRange.elementAt(4),
        speed: evRange.elementAt(5));
  }

  /// # `Stats` getStats(`int offset`)
  /// ## A function that returns the stats of the Pokemon.
  Stats getIvStats(int offset) {
    Iterable<int> ivRange = getRange(offset, 4);
    int total = combineBytesToInt32(ivRange.toList());
    return Stats(
        hp: total >> 0 & 31,
        attack: total >> 5 & 31,
        defense: total >> 10 & 31,
        specialAttack: total >> 15 & 31,
        specialDefense: total >> 20 & 31,
        speed: total >> 25 & 31);
  }

  /// # `int` getGender(`int offset`)
  /// ## A function that returns the gender of the Pokemon.
  int getGender(int offset) {
    Iterable<int> ivRange = getRange(offset, 4);
    int total = combineBytesToInt32(ivRange.toList());
    return total >> 30 & 11;
  }

  /// # `Future<List<int?>>` getMoves(`int offset`)
  /// ## A function that returns the moves of the Pokemon.
  /// This function returns a future that contains a list of move IDs.
  Future<List<int?>> getMoves(int offset) async {
    Iterable<int> moveRange = getRange(offset, 8);
    List<int?> moves = [];
    for (int i = 0; i < 4; i++) {
      int moveID = combineBytesToInt16(
          [moveRange.elementAt(i * 2), moveRange.elementAt(i * 2 + 1)]);
      moves.add(moveID);
    }
    return moves;
  }

  Trainer getOT(offset) {
    return Trainer(
        name: getString(offset + 0xB0, 24),
        gameID: get8BitInt(offset + 0xDF),
        id: get8BitInt(offset + 0x0C));
  }
}

/// # `PK6Data`
/// ## A class that represents the block that contains data for Generation 6.
/// This class extends the `Datablock` class and implements the `Gen3PokemonFormat` mixin.
/// Used in pk6 and gen 6 save files.
/// ```dart
/// PK6Data({required super.data});
/// ```
class PK6Data extends Datablock with Gen3PokemonFormat {
  PK6Data({required super.fileHandle});

  /// # `Future<dynamic>` parse()
  /// ## A function that parses the data in the block.
  /// This function returns a dynamic future.
  @override
  Future<dynamic> parse() async {
    List<int?> moveIDs = await getMoves(0x5A);
    int? trainerID = await PC.addTrainer(getOT(0x00));
    return Pokemon(
        otID: trainerID,
        speciesID: get16BitInt(0x08),
        nickName: getNickname(0x40),
        ev: getEvStats(0x1E),
        iv: getIvStats(0x74),
        move1ID: moveIDs[0]!,
        move2ID: moveIDs[1]!,
        move3ID: moveIDs[2]!,
        move4ID: moveIDs[3]!);
  }
}

class PK7Data extends Datablock with Gen3PokemonFormat {
  PK7Data({required super.fileHandle});

  /// # `Future<dynamic>` parse()
  /// ## A function that parses the data in the block.
  /// This function returns a dynamic future.
  @override
  Future<dynamic> parse() async {
    List<int?> moveIDs = await getMoves(0x5A);
    int? trainerID = await PC.addTrainer(getOT(0x00));
    return Pokemon(
        speciesID: get16BitInt(0x08),
        nickName: getNickname(0x40),
        ev: getEvStats(0x1E),
        iv: getIvStats(0x74),
        move1ID: moveIDs[0]!,
        move2ID: moveIDs[1]!,
        move3ID: moveIDs[2]!,
        move4ID: moveIDs[3]!,
        otID: trainerID);
  }
}
