import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../viewmodels/home_view_model.dart';
import '../viewmodels/home_view_state.dart';

final homeViewModelProvider = NotifierProvider<HomeViewModel, HomeViewState>(
  HomeViewModel.new,
);
