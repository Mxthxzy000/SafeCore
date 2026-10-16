import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/utils/error_messages.dart';

class LoadingView extends StatelessWidget {
  const LoadingView({super.key, this.message});

  final String? message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(),
            if (message != null) ...[
              const SizedBox(height: 12),
              Text(message!, style: AppText.bodySecondary),
            ],
          ],
        ),
      ),
    );
  }
}

class ErrorView extends StatelessWidget {
  const ErrorView({super.key, required this.error, this.onRetry});

  final Object error;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.cloud_off_outlined, size: 48, color: AppColors.textSecondary),
            const SizedBox(height: 12),
            Text(
              friendlyError(error),
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.slate),
            ),
            if (onRetry != null) ...[
              const SizedBox(height: 16),
              OutlinedButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh),
                label: const Text('Tentar novamente'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class EmptyView extends StatelessWidget {
  const EmptyView({super.key, required this.message, this.icon = Icons.inbox_outlined});

  final String message;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 44, color: AppColors.lightBlue),
            const SizedBox(height: 10),
            Text(
              message,
              textAlign: TextAlign.center,
              style: AppText.bodySecondary,
            ),
          ],
        ),
      ),
    );
  }
}

/// Carrega dados de um [Future] e trata carregamento, erro e recarga.
///
/// A tela informa como buscar ([load]) e como desenhar ([builder]);
/// `pull-to-refresh` e o botão "Tentar novamente" chamam [load] de novo.
class AsyncLoader<T> extends StatefulWidget {
  const AsyncLoader({super.key, required this.load, required this.builder, this.refresh});

  final Future<T> Function() load;

  /// Quando notificado, recarrega os dados sem mostrar o carregamento inicial.
  final Listenable? refresh;
  final Widget Function(BuildContext context, T data, Future<void> Function() reload) builder;

  @override
  State<AsyncLoader<T>> createState() => AsyncLoaderState<T>();
}

class AsyncLoaderState<T> extends State<AsyncLoader<T>> {
  T? _data;
  Object? _error;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    widget.refresh?.addListener(reload);
    reload();
  }

  @override
  void didUpdateWidget(covariant AsyncLoader<T> oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.refresh != widget.refresh) {
      oldWidget.refresh?.removeListener(reload);
      widget.refresh?.addListener(reload);
    }
  }

  @override
  void dispose() {
    widget.refresh?.removeListener(reload);
    super.dispose();
  }

  Future<void> reload() async {
    setState(() {
      _loading = _data == null;
      _error = null;
    });
    try {
      final data = await widget.load();
      if (!mounted) return;
      setState(() {
        _data = data;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e;
        _loading = false;
      });
      if (_data != null) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(friendlyError(e))));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const LoadingView();
    final data = _data;
    if (data == null) {
      return ErrorView(error: _error ?? 'Sem dados', onRetry: reload);
    }
    return widget.builder(context, data, reload);
  }
}
