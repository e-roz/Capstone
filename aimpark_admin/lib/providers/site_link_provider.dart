import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/constants/api_endpoints.dart';
import '../core/network/dio_client.dart';
import '../models/site_link.dart';

/// How often an open screen re-asks the cloud about the guard post.
const siteLinkRefreshEvery = Duration(seconds: 5);

/// The guard post as the cloud sees it, re-read every few seconds while a
/// screen shows it.
///
/// Null when the cloud can't say — an older cloud without the endpoint, or
/// the request failed — so the map falls back to saying nothing rather than
/// guessing "offline".
final siteLinkProvider = FutureProvider.autoDispose<SiteLink?>((ref) async {
  final timer = Timer(siteLinkRefreshEvery, ref.invalidateSelf);
  ref.onDispose(timer.cancel);

  try {
    final res = await ref.watch(dioProvider).get(ApiEndpoints.siteLink);
    return SiteLink.fromJson(res.data as Map<String, dynamic>);
  } on DioException {
    return null;
  }
});
