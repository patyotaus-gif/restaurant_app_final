import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:restaurant_models/restaurant_models.dart';

/// Central place for Firestore typed collection helpers.
extension AppFirestoreCollections on FirebaseFirestore {
  /// Typed access to the `menu_items` collection.
  CollectionReference<Product> get menuItemsRef => collection('menu_items')
      .withConverter<Product>(
        fromFirestore: (snapshot, _) =>
            Product.fromMap(snapshot.data() ?? const <String, dynamic>{},
                id: snapshot.id),
        toFirestore: (product, _) => product.toFirestore(),
      );

  /// Typed access to active store documents.
  CollectionReference<Store> get storesRef => collection('stores')
      .withConverter<Store>(
        fromFirestore: (snapshot, _) => Store.fromFirestore(snapshot),
        toFirestore: (store, _) => store.toFirestore(),
      );
}
