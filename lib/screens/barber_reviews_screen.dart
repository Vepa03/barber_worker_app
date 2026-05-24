import 'package:flutter/material.dart';
import '../services/api_client.dart';
import '../services/auth_storage.dart';
import 'barber_login_screen.dart';
import '../utils/theme_ext.dart';

// ── Constants ──────────────────────────────────────────────────────────────────
const _kGrey   = Color(0xFF8E8E93);
const _kBlue   = Color(0xFF3875F6);
const _kStar   = Color(0xFFF59E0B);

class BarberReviewsScreen extends StatefulWidget {
  const BarberReviewsScreen({super.key});
  @override
  State<BarberReviewsScreen> createState() => _BarberReviewsScreenState();
}

class _BarberReviewsScreenState extends State<BarberReviewsScreen> {
  List<Map<String, dynamic>> _reviews = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final data = await ApiClient.get('/barbers/me/reviews') as List;
      if (mounted) setState(() => _reviews = data.cast<Map<String, dynamic>>());
    } on ApiException catch (e) {
      if (e.statusCode == 401 && mounted) {
        await AuthStorage.clearTokens();
        Navigator.pushAndRemoveUntil(context,
            MaterialPageRoute(builder: (_) => const BarberLoginScreen()),
            (_) => false);
        return;
      }
    } catch (_) {}
    if (mounted) setState(() => _loading = false);
  }

  // ── Stats ─────────────────────────────────────────────────────────────────────
  double get _avg {
    if (_reviews.isEmpty) return 0;
    final sum = _reviews.fold(0.0, (s, r) => s + ((r['rating'] as num?)?.toDouble() ?? 0));
    return sum / _reviews.length;
  }

  Map<int, int> get _counts {
    final m = {5: 0, 4: 0, 3: 0, 2: 0, 1: 0};
    for (final r in _reviews) {
      final v = (r['rating'] as num?)?.toInt() ?? 0;
      if (m.containsKey(v)) m[v] = m[v]! + 1;
    }
    return m;
  }

  // ── Build ─────────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.kBg,
      body: SafeArea(
        child: Column(children: [
          _buildHeader(),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator(color: _kBlue, strokeWidth: 2.5))
                : RefreshIndicator(
                    onRefresh: _load,
                    color: _kBlue,
                    child: _reviews.isEmpty
                        ? _buildEmpty()
                        : ListView.builder(
                            padding: const EdgeInsets.only(bottom: 32),
                            itemCount: _reviews.length + 1,
                            itemBuilder: (_, i) =>
                                i == 0 ? _buildSummary() : _buildCard(_reviews[i - 1]),
                          ),
                  ),
          ),
        ]),
      ),
    );
  }

  // ── Header ────────────────────────────────────────────────────────────────────
  Widget _buildHeader() => Padding(
    padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
    child: Row(children: [
      GestureDetector(
        onTap: () => Navigator.pop(context),
        child: Container(
          width: 36, height: 36,
          decoration: BoxDecoration(
            color: context.kSurface, borderRadius: BorderRadius.circular(10),
            border: Border.all(color: context.kBorder),
          ),
          child: Icon(Icons.chevron_left, size: 20, color: context.kText),
        ),
      ),
      const SizedBox(width: 12),
      Expanded(
        child: Text('Reviews', style: TextStyle(
            fontSize: 24, fontWeight: FontWeight.w800,
            color: context.kText, letterSpacing: -0.5)),
      ),
      Container(
        width: 36, height: 36,
        decoration: BoxDecoration(
          color: context.kSurface, borderRadius: BorderRadius.circular(10),
          border: Border.all(color: context.kBorder),
        ),
        child: Icon(Icons.tune_rounded, size: 18, color: context.kText),
      ),
    ]),
  );

  // ── Summary card ──────────────────────────────────────────────────────────────
  Widget _buildSummary() {
    final avg    = _avg;
    final counts = _counts;
    final total  = _reviews.length;
    final maxCnt = counts.values.fold(0, (a, b) => a > b ? a : b);

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: context.kSurface,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(
          color: Colors.black.withValues(alpha: 0.04),
          blurRadius: 8, offset: const Offset(0, 2),
        )],
      ),
      child: Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
        // ── Left: big rating ──────────────────────────────────────────────
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(avg.toStringAsFixed(1), style: TextStyle(
              fontSize: 52, fontWeight: FontWeight.w900,
              color: context.kText, height: 1.0, letterSpacing: -2)),
          const SizedBox(height: 6),
          _Stars(rating: avg, size: 20),
          const SizedBox(height: 4),
          Text('$total review${total != 1 ? 's' : ''}',
              style: const TextStyle(fontSize: 13, color: _kGrey,
                  fontWeight: FontWeight.w500)),
        ]),
        const SizedBox(width: 24),
        // ── Right: bar chart ──────────────────────────────────────────────
        Expanded(
          child: Column(
            children: [5, 4, 3, 2, 1].map((star) {
              final cnt    = counts[star] ?? 0;
              final frac   = maxCnt > 0 ? cnt / maxCnt : 0.0;
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 2.5),
                child: Row(children: [
                  Text('$star', style: const TextStyle(
                      fontSize: 11, color: _kGrey, fontWeight: FontWeight.w500)),
                  const SizedBox(width: 6),
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(3),
                      child: LinearProgressIndicator(
                        value: frac,
                        minHeight: 6,
                        backgroundColor: const Color(0xFFF0F0F0),
                        valueColor: const AlwaysStoppedAnimation(_kStar),
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  SizedBox(
                    width: 16,
                    child: Text('$cnt', textAlign: TextAlign.right,
                        style: const TextStyle(fontSize: 11, color: _kGrey,
                            fontWeight: FontWeight.w500)),
                  ),
                ]),
              );
            }).toList(),
          ),
        ),
      ]),
    );
  }

  // ── Review card ───────────────────────────────────────────────────────────────
  Widget _buildCard(Map<String, dynamic> r) {
    final name    = (r['authorName']   as String?) ?? 'Customer';
    final avatar  = (r['authorAvatar'] as String?) ?? '';
    final rating  = (r['rating']       as num?)?.toInt() ?? 0;
    final comment = (r['comment']      as String?) ?? '';
    final created = r['createdAt'] != null
        ? DateTime.tryParse(r['createdAt'].toString())?.toLocal()
        : null;

    final ini    = _initials(name);
    final aColor = _avatarColor(name);
    final ago    = created != null ? _timeAgo(created) : '';

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 10),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.kSurface,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [BoxShadow(
          color: Colors.black.withValues(alpha: 0.04),
          blurRadius: 8, offset: const Offset(0, 2),
        )],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // ── Top row: avatar + name/meta + stars ───────────────────────────
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          // Avatar
          Container(
            width: 44, height: 44,
            decoration: BoxDecoration(
              color: aColor.withValues(alpha: 0.15),
              shape: BoxShape.circle,
              image: avatar.isNotEmpty
                  ? DecorationImage(image: NetworkImage(avatar), fit: BoxFit.cover)
                  : null,
            ),
            child: avatar.isEmpty
                ? Center(child: Text(ini, style: TextStyle(
                    fontSize: 14, fontWeight: FontWeight.w800, color: aColor)))
                : null,
          ),
          const SizedBox(width: 12),
          // Name + meta
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(name, style: TextStyle(
                  fontSize: 15, fontWeight: FontWeight.w700, color: context.kText)),
              const SizedBox(height: 2),
              Text(ago, style: const TextStyle(
                  fontSize: 12, color: _kGrey)),
            ]),
          ),
          // Stars
          _Stars(rating: rating.toDouble(), size: 14),
        ]),
        // ── Comment ───────────────────────────────────────────────────────
        if (comment.isNotEmpty) ...[
          const SizedBox(height: 12),
          Text('"$comment"', style: TextStyle(
              fontSize: 14, color: context.kText, height: 1.55,
              fontStyle: FontStyle.normal)),
        ],
      ]),
    );
  }

  // ── Empty ─────────────────────────────────────────────────────────────────────
  Widget _buildEmpty() => Center(
    child: Column(mainAxisSize: MainAxisSize.min, children: [
      const Text('⭐', style: TextStyle(fontSize: 52)),
      const SizedBox(height: 14),
      Text('No reviews yet', style: TextStyle(
          fontSize: 16, fontWeight: FontWeight.w700, color: context.kText)),
      const SizedBox(height: 6),
      const Text('Customer reviews will appear here', style: TextStyle(
          fontSize: 13, color: _kGrey)),
    ]),
  );

  // ── Helpers ───────────────────────────────────────────────────────────────────
  static const _palette = [
    Color(0xFF3875F6),
    Color(0xFF8B5CF6),
    Color(0xFFEC4899),
    Color(0xFF14B8A6),
    Color(0xFFF59E0B),
    Color(0xFF22C55E),
  ];

  static Color _avatarColor(String name) {
    if (name.isEmpty) return _kBlue;
    int h = 0;
    for (final c in name.runes) { h = (h * 31 + c) & 0xFFFFFFFF; }
    return _palette[h % _palette.length];
  }

  static String _initials(String name) {
    final p = name.trim().split(RegExp(r'\s+'));
    if (p.length >= 2) return '${p[0][0]}${p[1][0]}'.toUpperCase();
    return p.isNotEmpty && p[0].isNotEmpty ? p[0][0].toUpperCase() : '?';
  }

  static String _timeAgo(DateTime dt) {
    final d = DateTime.now().difference(dt);
    if (d.inDays >= 365) return '${d.inDays ~/ 365} year${d.inDays ~/ 365 > 1 ? 's' : ''} ago';
    if (d.inDays >= 30)  return '${d.inDays ~/ 30} month${d.inDays ~/ 30 > 1 ? 's' : ''} ago';
    if (d.inDays >= 14)  return '${d.inDays ~/ 7} weeks ago';
    if (d.inDays >= 7)   return '1 week ago';
    if (d.inDays >= 2)   return '${d.inDays} days ago';
    if (d.inDays == 1)   return '1 day ago';
    if (d.inHours >= 2)  return '${d.inHours} hours ago';
    if (d.inHours == 1)  return '1 hour ago';
    if (d.inMinutes >= 2) return '${d.inMinutes} minutes ago';
    return 'Just now';
  }
}

// ── Stars widget ──────────────────────────────────────────────────────────────
class _Stars extends StatelessWidget {
  final double rating;
  final double size;
  const _Stars({required this.rating, required this.size});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(5, (i) {
        final full  = i < rating.floor();
        final half  = !full && i < rating && (rating - rating.floor()) >= 0.5;
        return Icon(
          full ? Icons.star_rounded
               : half ? Icons.star_half_rounded
               : Icons.star_outline_rounded,
          size: size, color: _kStar,
        );
      }),
    );
  }
}
