import 'dart:async';

import 'package:material_ui/material_ui.dart';

import '../../glass_panel.dart';
import '../../storage.dart';
import '../../theme.dart';
import 'weather_api.dart';

const _dayNames = ['Pzt', 'Sal', 'Çar', 'Per', 'Cum', 'Cmt', 'Paz'];

/// Anlık hava + 5 günlük tahmin. Şehir adına tıklayınca şehir aranır.
class WeatherWidget extends StatefulWidget {
  const WeatherWidget({
    super.key,
    this.api = const WeatherApi(),
    this.store,
    this.live = true,
    this.initialData,
  });

  final WeatherApi api;
  final JsonFile? store;
  final bool live;
  final WeatherData? initialData;

  @override
  State<WeatherWidget> createState() => _WeatherWidgetState();
}

class _WeatherWidgetState extends State<WeatherWidget> {
  static const _refreshEvery = Duration(minutes: 15);

  late GeoPlace _place;
  WeatherData? _data;
  String? _error;
  bool _loading = false;
  Timer? _timer;

  bool _searching = false;
  final _searchController = TextEditingController();
  List<GeoPlace> _results = const [];
  Timer? _searchDebounce;
  bool _searchLoading = false;

  @override
  void initState() {
    super.initState();
    _data = widget.initialData;
    _place = GeoPlace.fromJson(widget.store?.read()['place']) ??
        widget.initialData?.place ??
        GeoPlace.istanbul;
    if (widget.live) {
      _load();
      _timer = Timer.periodic(_refreshEvery, (_) => _load());
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _searchDebounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    if (_loading) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final data = await widget.api.fetch(_place);
      if (!mounted) return;
      setState(() => _data = data);
    } catch (_) {
      if (!mounted) return;
      setState(() => _error = 'Hava durumu alınamadı. İnternet bağlantını kontrol et.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _onSearchChanged(String text) {
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 400), () async {
      if (!mounted) return;
      setState(() => _searchLoading = true);
      try {
        final results = await widget.api.search(text);
        if (!mounted) return;
        setState(() => _results = results);
      } catch (_) {
        if (!mounted) return;
        setState(() => _results = const []);
      } finally {
        if (mounted) setState(() => _searchLoading = false);
      }
    });
  }

  void _select(GeoPlace place) {
    widget.store?.update((data) => data['place'] = place.toJson());
    setState(() {
      _place = place;
      _searching = false;
      _results = const [];
      _searchController.clear();
    });
    _load();
  }

  @override
  Widget build(BuildContext context) {
    return _searching ? _buildSearch() : _buildWeather();
  }

  Widget _buildSearch() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        GlassHeader(
          icon: Icons.search_rounded,
          title: 'Şehir seç',
          trailing: _IconBtn(
            icon: Icons.close_rounded,
            tooltip: 'Vazgeç',
            onTap: () => setState(() {
              _searching = false;
              _results = const [];
            }),
          ),
        ),
        const SizedBox(height: 10),
        TextField(
          controller: _searchController,
          autofocus: true,
          onChanged: _onSearchChanged,
          onSubmitted: (_) {
            if (_results.isNotEmpty) _select(_results.first);
          },
          style: const TextStyle(fontSize: 14),
          decoration: InputDecoration(
            isDense: true,
            hintText: 'Örn. Ankara, Berlin…',
            hintStyle: TextStyle(color: GlassColors.soft(0.4)),
            filled: true,
            fillColor: Colors.white.withValues(alpha: 0.08),
            prefixIcon: const Icon(Icons.location_on_outlined, size: 18),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide.none,
            ),
          ),
        ),
        const SizedBox(height: 8),
        if (_searchLoading)
          const Padding(
            padding: EdgeInsets.all(12),
            child: Center(
              child: SizedBox.square(
                dimension: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
          ),
        Expanded(
          child: ListView(
            padding: EdgeInsets.zero,
            children: [
              for (final p in _results)
                InkWell(
                  borderRadius: BorderRadius.circular(8),
                  onTap: () => _select(p),
                  child: Padding(
                    padding:
                        const EdgeInsets.symmetric(vertical: 7, horizontal: 6),
                    child: Row(
                      children: [
                        const Icon(Icons.place_rounded,
                            size: 16, color: GlassColors.accent2),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(p.name,
                                  style: const TextStyle(fontSize: 13)),
                              if (p.subtitle.isNotEmpty)
                                Text(
                                  p.subtitle,
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: GlassColors.soft(0.55),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildWeather() {
    final data = _data;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        GlassHeader(
          icon: Icons.place_rounded,
          title: _place.name,
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _IconBtn(
                icon: Icons.search_rounded,
                tooltip: 'Şehir değiştir',
                onTap: () => setState(() => _searching = true),
              ),
              _IconBtn(
                icon: Icons.refresh_rounded,
                tooltip: 'Yenile',
                onTap: _load,
              ),
            ],
          ),
        ),
        const SizedBox(height: 6),
        Expanded(
          child: data == null
              ? Center(
                  child: _loading
                      ? const SizedBox.square(
                          dimension: 22,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Text(
                          _error ?? 'Veri yok',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 13,
                            color: GlassColors.soft(0.7),
                          ),
                        ),
                )
              : _WeatherBody(data: data),
        ),
      ],
    );
  }
}

class _WeatherBody extends StatelessWidget {
  const _WeatherBody({required this.data});

  final WeatherData data;

  @override
  Widget build(BuildContext context) {
    final color = weatherColor(data.code, isDay: data.isDay);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Icon(
              weatherIcon(data.code, isDay: data.isDay),
              size: 54,
              color: color,
              shadows: [
                Shadow(color: color.withValues(alpha: 0.5), blurRadius: 18),
              ],
            ),
            const SizedBox(width: 12),
            Text(
              '${data.temperature.round()}°',
              style: const TextStyle(
                fontSize: 54,
                height: 1,
                fontWeight: FontWeight.w300,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    weatherLabel(data.code),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Hissedilen ${data.feelsLike.round()}°',
                    style: TextStyle(
                      fontSize: 12,
                      color: GlassColors.soft(0.65),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            _Chip(icon: Icons.water_drop_rounded, text: '%${data.humidity}'),
            const SizedBox(width: 8),
            _Chip(icon: Icons.air_rounded, text: '${data.wind.round()} km/s'),
            if (data.days.isNotEmpty) ...[
              const SizedBox(width: 8),
              _Chip(
                icon: Icons.thermostat_rounded,
                text: '${data.days.first.max.round()}° / '
                    '${data.days.first.min.round()}°',
              ),
            ],
          ],
        ),
        const Spacer(),
        Divider(height: 1, color: Colors.white.withValues(alpha: 0.12)),
        const SizedBox(height: 10),
        Row(
          children: [
            for (var i = 0; i < data.days.length && i < 5; i++)
              Expanded(child: _DayColumn(day: data.days[i], today: i == 0)),
          ],
        ),
      ],
    );
  }
}

class _DayColumn extends StatelessWidget {
  const _DayColumn({required this.day, required this.today});

  final DailyForecast day;
  final bool today;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          today ? 'Bugün' : _dayNames[day.date.weekday - 1],
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: today ? GlassColors.accent2 : GlassColors.soft(0.7),
          ),
        ),
        const SizedBox(height: 6),
        Icon(weatherIcon(day.code), size: 20, color: weatherColor(day.code)),
        const SizedBox(height: 6),
        Text(
          '${day.max.round()}°',
          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
        ),
        Text(
          '${day.min.round()}°',
          style: TextStyle(fontSize: 12, color: GlassColors.soft(0.5)),
        ),
      ],
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: GlassColors.accent2),
          const SizedBox(width: 4),
          Text(text, style: const TextStyle(fontSize: 12)),
        ],
      ),
    );
  }
}

class _IconBtn extends StatelessWidget {
  const _IconBtn({
    required this.icon,
    required this.tooltip,
    required this.onTap,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: InkResponse(
        onTap: onTap,
        radius: 14,
        child: Padding(
          padding: const EdgeInsets.all(3),
          child: Icon(icon, size: 16, color: GlassColors.soft(0.75)),
        ),
      ),
    );
  }
}
