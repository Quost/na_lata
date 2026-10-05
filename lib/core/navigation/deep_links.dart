import 'dart:async';

import 'package:flutter/services.dart';

import '../../data/clients/app_failure.dart';
import '../../data/clients/backend_client.dart';
import '../../data/list_repository.dart';
import '../../core/contracts.dart';
import '../../core/models.dart';
import '../../features/lists/list_models.dart';

const deepLinkScheme = 'nalata';
const _barcodePattern = r'^[0-9]{8,14}$';
final _uuidPattern = RegExp(
  r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
);

sealed class DeepLinkRoute {
  const DeepLinkRoute();

  static DeepLinkRoute? tryParse(String value) {
    late final Uri uri;
    try {
      uri = Uri.parse(value);
    } on FormatException {
      return null;
    }
    if (uri.scheme != deepLinkScheme ||
        uri.userInfo.isNotEmpty ||
        uri.hasPort ||
        uri.hasQuery ||
        uri.hasFragment ||
        uri.pathSegments.length != 1) {
      return null;
    }

    final id = uri.pathSegments.single;
    switch (uri.host) {
      case 'product':
        return RegExp(_barcodePattern).hasMatch(id)
            ? ProductDeepLink(id)
            : null;
      case 'profile':
        return _uuidPattern.hasMatch(id)
            ? ProfileDeepLink(id.toLowerCase())
            : null;
      case 'list':
        return _uuidPattern.hasMatch(id)
            ? ListDeepLink(id.toLowerCase())
            : null;
      default:
        return null;
    }
  }

  static Uri product(String barcode) {
    if (!RegExp(_barcodePattern).hasMatch(barcode)) {
      throw ArgumentError.value(barcode, 'barcode', 'Invalid product barcode.');
    }
    return Uri(
      scheme: deepLinkScheme,
      host: 'product',
      pathSegments: [barcode],
    );
  }

  static Uri profile(String id) {
    if (!_uuidPattern.hasMatch(id)) {
      throw ArgumentError.value(id, 'id', 'Invalid profile UUID.');
    }
    return Uri(
      scheme: deepLinkScheme,
      host: 'profile',
      pathSegments: [id.toLowerCase()],
    );
  }

  static Uri list(String id) {
    if (!_uuidPattern.hasMatch(id)) {
      throw ArgumentError.value(id, 'id', 'Invalid list UUID.');
    }
    return Uri(
      scheme: deepLinkScheme,
      host: 'list',
      pathSegments: [id.toLowerCase()],
    );
  }
}

final class ProductDeepLink extends DeepLinkRoute {
  const ProductDeepLink(this.barcode);
  final String barcode;
}

final class ProfileDeepLink extends DeepLinkRoute {
  const ProfileDeepLink(this.id);
  final String id;
}

final class ListDeepLink extends DeepLinkRoute {
  const ListDeepLink(this.id);
  final String id;
}

class SharedProfile {
  const SharedProfile({required this.id, required this.nickname});
  final String id;
  final String nickname;
}

class SharedProductList {
  const SharedProductList({required this.list, required this.barcodes});
  final ProductList list;
  final List<String> barcodes;
}

sealed class DeepLinkDestination {
  const DeepLinkDestination();
}

final class ProductDestination extends DeepLinkDestination {
  const ProductDestination(this.product);
  final Product product;
}

final class ProfileDestination extends DeepLinkDestination {
  const ProfileDestination(this.profile);
  final SharedProfile profile;
}

final class ListDestination extends DeepLinkDestination {
  const ListDestination(this.sharedList);
  final SharedProductList sharedList;
}

abstract interface class DeepLinkContentSource {
  Future<Product?> product(String barcode);
  Future<SharedProfile?> profile(String id);
  Future<SharedProductList?> list(String id);
}

class RepositoryDeepLinkContentSource implements DeepLinkContentSource {
  const RepositoryDeepLinkContentSource({
    required this.products,
    this.lists,
    this.backend,
  });

  final ProductRepository products;
  final ListRepository? lists;
  final BackendClient? backend;

  @override
  Future<Product?> product(String barcode) => products.byBarcode(barcode);

  @override
  Future<SharedProfile?> profile(String id) async {
    final client = backend;
    if (client == null) return null;
    final row = await client.request<Map<String, dynamic>?>(
      (db) =>
          db.from('profiles').select('id,nickname').eq('id', id).maybeSingle(),
    );
    if (row == null) return null;
    return SharedProfile(
      id: row['id'] as String,
      nickname: row['nickname'] as String,
    );
  }

  @override
  Future<SharedProductList?> list(String id) async {
    final repository = lists;
    if (repository == null) return null;
    final productList = await repository.byId(id);
    if (productList == null) return null;
    final barcodes = await repository.items(id);
    return SharedProductList(list: productList, barcodes: barcodes);
  }
}

class DeepLinkResolver {
  const DeepLinkResolver(this.source);

  final DeepLinkContentSource source;

  Future<DeepLinkDestination?> resolve(String value) async {
    final route = DeepLinkRoute.tryParse(value);
    if (route == null) return null;
    try {
      return switch (route) {
        ProductDeepLink(:final barcode) => await _product(barcode),
        ProfileDeepLink(:final id) => await _profile(id),
        ListDeepLink(:final id) => await _list(id),
      };
    } on AppFailure {
      return null;
    } on FeaturePending {
      return null;
    }
  }

  Future<DeepLinkDestination?> _product(String barcode) async {
    final product = await source.product(barcode);
    return product == null ? null : ProductDestination(product);
  }

  Future<DeepLinkDestination?> _profile(String id) async {
    final profile = await source.profile(id);
    return profile == null ? null : ProfileDestination(profile);
  }

  Future<DeepLinkDestination?> _list(String id) async {
    final sharedList = await source.list(id);
    return sharedList == null ? null : ListDestination(sharedList);
  }
}

abstract interface class DeepLinkPlatform {
  Future<String?> initialLink();
  Stream<String> get links;
  Future<void> share(Uri uri);
}

class AndroidDeepLinkPlatform implements DeepLinkPlatform {
  const AndroidDeepLinkPlatform();

  static const _methods = MethodChannel('br.edu.adsstech.na_lata/deep_links');
  static const _events = EventChannel(
    'br.edu.adsstech.na_lata/deep_link_events',
  );

  @override
  Future<String?> initialLink() async {
    try {
      return await _methods.invokeMethod<String>('getInitialLink');
    } on MissingPluginException {
      return null;
    }
  }

  @override
  Stream<String> get links => _events.receiveBroadcastStream().transform(
    StreamTransformer<dynamic, String>.fromHandlers(
      handleData: (value, sink) {
        if (value is String) sink.add(value);
      },
      handleError: (Object error, StackTrace stackTrace, sink) {
        if (error is! MissingPluginException) {
          sink.addError(error, stackTrace);
        }
      },
    ),
  );

  @override
  Future<void> share(Uri uri) async {
    await _methods.invokeMethod<void>('share', {'text': uri.toString()});
  }
}

class NativeShare {
  const NativeShare(this.platform);

  final DeepLinkPlatform platform;

  Future<void> share(Uri uri) => platform.share(uri);
}
