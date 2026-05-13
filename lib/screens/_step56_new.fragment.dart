  Widget _buildStepFive() {
    return _step5Ui == _Step5Ui.review
        ? _buildStepFiveReview()
        : _buildStepFiveHub();
  }

  Widget _buildStepFiveHub() {
    const primaryBlue = Color(0xFF2D7DFF);
    const purple = Color(0xFF7B68EE);
    final zi = (_addItemsZoneIndex ?? 0).clamp(0, _sections.length - 1);
    final zone = _sections[zi];
    final r = _analysisResult;
    final modelLine = '${r?.brand ?? ''} ${r?.model ?? ''}'.trim();
    final displayModel = modelLine.isEmpty ? 'Your fridge' : modelLine;

    Widget bigCard({
      required Color bg,
      required Color accent,
      required IconData icon,
      required String badge,
      required String title,
      required String subtitle,
      required VoidCallback onTap,
    }) {
      return Expanded(
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(20),
            child: Container(
              padding: const EdgeInsets.fromLTRB(12, 14, 12, 12),
              decoration: BoxDecoration(
                color: bg,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.white.withOpacity(0.95)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.06),
                    blurRadius: 14,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: const BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(icon, color: accent, size: 24),
                      ),
                      const Spacer(),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: accent.withOpacity(0.22),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          badge,
                          style: TextStyle(
                            fontSize: 9.5,
                            fontWeight: FontWeight.w900,
                            color: accent,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                      color: Color(0xFF1A2B4D),
                      height: 1.15,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 11.5,
                      height: 1.35,
                      fontWeight: FontWeight.w500,
                      color: Colors.black.withOpacity(0.48),
                    ),
                  ),
                  const Spacer(),
                  Align(
                    alignment: Alignment.bottomRight,
                    child: CircleAvatar(
                      radius: 22,
                      backgroundColor: accent,
                      child: const Icon(
                        Icons.arrow_forward_rounded,
                        color: Colors.white,
                        size: 22,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    final extraScanned = _shelfScannedItems
        .where(
          (s) => !_step5QuickChips.any((q) => q.$2 == s.name),
        )
        .toList();

    return ColoredBox(
      color: const Color(0xFFF4F7FC),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(14, 4, 14, 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                  color: primaryBlue.withOpacity(0.25),
                  width: 1.2,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 14,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: SizedBox(
                      width: 56,
                      height: 64,
                      child: _selectedImageBytes != null
                          ? Image.memory(
                              _selectedImageBytes!,
                              fit: BoxFit.cover,
                            )
                          : ColoredBox(
                              color: Colors.grey.shade200,
                              child: const Icon(Icons.kitchen_rounded, size: 28),
                            ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.view_stream_rounded,
                                size: 18, color: primaryBlue.withOpacity(0.9)),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text.rich(
                                TextSpan(
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                    color: Colors.black.withOpacity(0.55),
                                  ),
                                  children: [
                                    const TextSpan(text: 'Adding to: '),
                                    TextSpan(
                                      text: zone,
                                      style: const TextStyle(
                                        color: Color(0xFF1A2B4D),
                                        fontWeight: FontWeight.w900,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(
                          displayModel,
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w900,
                            color: Color(0xFF1A2B4D),
                            height: 1.2,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(Icons.info_outline_rounded,
                                size: 16,
                                color: Colors.black.withOpacity(0.38)),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                'Items added here will appear on your ${zone.toLowerCase()}.',
                                style: TextStyle(
                                  fontSize: 11.5,
                                  height: 1.35,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.black.withOpacity(0.45),
                                ),
                              ),
                            ),
                          ],
                        ),
                        Align(
                          alignment: Alignment.centerRight,
                          child: TextButton(
                            onPressed: _showStep5ChangeShelfSheet,
                            child: const Text(
                              'Change shelf ›',
                              style: TextStyle(fontWeight: FontWeight.w800),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),
            const Text(
              'How would you like to add items?',
              style: TextStyle(
                fontSize: 19,
                fontWeight: FontWeight.w900,
                color: Color(0xFF1A2B4D),
                height: 1.2,
              ),
            ),
            const SizedBox(height: 12),
            IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  bigCard(
                    bg: const Color(0xFFE8F4FF),
                    accent: primaryBlue,
                    icon: Icons.photo_camera_rounded,
                    badge: '✨ AI Powered',
                    title: 'Scan Items',
                    subtitle:
                        'Use camera to detect multiple items at once',
                    onTap: _openShelfScan,
                  ),
                  const SizedBox(width: 12),
                  bigCard(
                    bg: const Color(0xFFF0EBFF),
                    accent: purple,
                    icon: Icons.photo_library_rounded,
                    badge: '✨ Quick & Easy',
                    title: 'Upload Photo',
                    subtitle:
                        'Upload a clear photo of your ${zone.toLowerCase()}',
                    onTap: _openShelfPhotoUpload,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            Material(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              child: InkWell(
                borderRadius: BorderRadius.circular(16),
                onTap: _openManualAddOnStep5,
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                  child: Row(
                    children: [
                      Icon(Icons.edit_rounded,
                          color: Colors.black.withOpacity(0.55)),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Add Manually',
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w900,
                                color: Color(0xFF1A2B4D),
                              ),
                            ),
                            Text(
                              'Search and add items yourself',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.black.withOpacity(0.45),
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Icon(Icons.chevron_right_rounded,
                          color: Colors.black.withOpacity(0.35)),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 18),
            Text(
              'Common items on ${zone.toLowerCase()} ✨',
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w900,
                color: Color(0xFF1A2B4D),
              ),
            ),
            const SizedBox(height: 10),
            SizedBox(
              height: 40,
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: [
                  for (final q in _step5QuickChips)
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ActionChip(
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        label: Text('${q.$1} ${q.$2}'),
                        onPressed: () {
                          setState(() {
                            _shelfScannedItems.add(
                              ShelfScanItem(name: q.$2, category: q.$3),
                            );
                          });
                        },
                      ),
                    ),
                  for (final s in extraScanned)
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ActionChip(
                        label: Text(s.name),
                        onPressed: () {
                          setState(() {
                            _step5ReviewLines
                              ..clear()
                              ..add(_Step5ReviewLine(
                                  name: s.name, category: s.category));
                            _step5Ui = _Step5Ui.review;
                            _step5ReviewContinueEnabled = false;
                          });
                        },
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Tap any item above to add it quickly',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Colors.black.withOpacity(0.42),
              ),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              decoration: BoxDecoration(
                color: const Color(0xFFE8F1FF),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(
                children: [
                  const Text('🐧', style: TextStyle(fontSize: 22)),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Tip: You can scan your shelf to add multiple items or add them manually one by one.',
                      style: TextStyle(
                        fontSize: 12,
                        height: 1.35,
                        fontWeight: FontWeight.w600,
                        color: Colors.black.withOpacity(0.52),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: () => _nextStep(),
              style: FilledButton.styleFrom(
                backgroundColor: primaryBlue,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              child: const Text(
                'Skip for now',
                style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStepFiveReview() {
    const primaryBlue = Color(0xFF2D7DFF);
    final zi = (_addItemsZoneIndex ?? 0).clamp(0, _sections.length - 1);
    final zone = _sections[zi];
    final imgBytes = _shelfReviewImageBytes ?? _selectedImageBytes;
    final n = _step5ReviewLines.length;
    final canContinue =
        _step5ReviewContinueEnabled && _step5ReviewLines.isNotEmpty;

    Future<void> addMissing() async {
      final c = TextEditingController();
      final ok = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Add missing item'),
          content: TextField(
            controller: c,
            decoration: const InputDecoration(hintText: 'Item name'),
            autofocus: true,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Add'),
            ),
          ],
        ),
      );
      final name = c.text.trim();
      c.dispose();
      if (ok != true || !mounted || name.isEmpty) return;
      setState(() {
        _step5ReviewLines
            .add(_Step5ReviewLine(name: name, category: 'Other'));
        _step5ReviewContinueEnabled = true;
      });
    }

    return ColoredBox(
      color: const Color(0xFFF4F7FC),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(14, 4, 14, 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text.rich(
              TextSpan(
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                  color: Color(0xFF1A2B4D),
                  height: 1.2,
                ),
                children: [
                  const TextSpan(text: 'Friji scanned your '),
                  TextSpan(
                    text: '$zone!',
                    style: const TextStyle(color: Color(0xFF2D7DFF)),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Review the items we found and confirm what\'s in your fridge.',
              style: TextStyle(
                fontSize: 13.5,
                height: 1.4,
                fontWeight: FontWeight.w600,
                color: Colors.black.withOpacity(0.48),
              ),
            ),
            const SizedBox(height: 14),
            ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: AspectRatio(
                aspectRatio: 4 / 3,
                child: imgBytes != null
                    ? Image.memory(imgBytes, fit: BoxFit.cover)
                    : ColoredBox(
                        color: Colors.grey.shade300,
                        child: Icon(Icons.kitchen_rounded,
                            size: 56, color: Colors.grey.shade500),
                      ),
              ),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.black.withOpacity(0.06)),
              ),
              child: Row(
                children: [
                  Icon(Icons.kitchen_rounded,
                      color: primaryBlue.withOpacity(0.85), size: 28),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          zone,
                          style: const TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w900,
                            color: Color(0xFF1A2B4D),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _step5ReviewCategorySummary(),
                          style: TextStyle(
                            fontSize: 12,
                            height: 1.3,
                            fontWeight: FontWeight.w600,
                            color: Colors.black.withOpacity(0.45),
                          ),
                        ),
                      ],
                    ),
                  ),
                  TextButton(
                    onPressed: _showStep5ChangeShelfSheet,
                    child: const Text(
                      'Change shelf ›',
                      style: TextStyle(fontWeight: FontWeight.w800),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Items found ($n)',
              style: const TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w900,
                color: Color(0xFF1A2B4D),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'We found these items. Add, edit, or remove any that aren\'t correct.',
              style: TextStyle(
                fontSize: 12.5,
                height: 1.35,
                fontWeight: FontWeight.w600,
                color: Colors.black.withOpacity(0.45),
              ),
            ),
            const SizedBox(height: 10),
            for (var i = 0; i < _step5ReviewLines.length; i++)
              _buildStep5ReviewRow(i),
            if (n > 3)
              Padding(
                padding: const EdgeInsets.only(top: 6, bottom: 4),
                child: Text(
                  'Scroll to see more items',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: Colors.black.withOpacity(0.38),
                  ),
                ),
              ),
            const SizedBox(height: 8),
            Material(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              child: InkWell(
                borderRadius: BorderRadius.circular(14),
                onTap: addMissing,
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 18,
                        backgroundColor: const Color(0xFFE8F1FF),
                        child: Icon(Icons.add_rounded, color: primaryBlue),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Add missing items',
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w900,
                                color: Color(0xFF1A2B4D),
                              ),
                            ),
                            Text(
                              'Can\'t find something? Add it manually.',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.black.withOpacity(0.45),
                              ),
                            ),
                          ],
                        ),
                      ),
                      Icon(Icons.chevron_right_rounded,
                          color: Colors.black.withOpacity(0.35)),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: _showStep5ChangeShelfSheet,
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                          vertical: 12, horizontal: 8),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    child: Column(
                      children: [
                        Icon(Icons.kitchen_outlined,
                            color: Colors.black.withOpacity(0.55)),
                        const SizedBox(height: 4),
                        const Text(
                          'Choose another shelf',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 12,
                          ),
                        ),
                        Text(
                          'Middle, door, etc.',
                          style: TextStyle(
                            fontSize: 10,
                            color: Colors.black.withOpacity(0.4),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  flex: 2,
                  child: FilledButton(
                    onPressed: canContinue ? () => _nextStep() : null,
                    style: FilledButton.styleFrom(
                      backgroundColor: primaryBlue,
                      disabledBackgroundColor: Colors.grey.shade300,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          'Continue',
                          style: TextStyle(
                            fontWeight: FontWeight.w900,
                            fontSize: 16,
                          ),
                        ),
                        SizedBox(width: 8),
                        Icon(Icons.arrow_forward_rounded, size: 22),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStep5ReviewRow(int i) {
    const primaryBlue = Color(0xFF2D7DFF);
    final line = _step5ReviewLines[i];
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: () => setState(() => _step5ReviewContinueEnabled = true),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: Container(
                    width: 48,
                    height: 48,
                    color: const Color(0xFFF4F7FC),
                    child: Center(
                      child: Text(
                        line.name.isNotEmpty
                            ? line.name[0].toUpperCase()
                            : '?',
                        style: const TextStyle(
                          fontWeight: FontWeight.w900,
                          fontSize: 18,
                          color: Color(0xFF4A90E2),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              line.name,
                              style: const TextStyle(
                                fontWeight: FontWeight.w900,
                                fontSize: 15,
                                color: Color(0xFF1A2B4D),
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF0F2F7),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              line.category,
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w800,
                                color: Colors.black.withOpacity(0.45),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Container(
                            decoration: BoxDecoration(
                              color: const Color(0xFFE8F1FF),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  visualDensity: VisualDensity.compact,
                                  onPressed: () {
                                    setState(() {
                                      if (line.qty > 1) line.qty--;
                                      _step5ReviewContinueEnabled = true;
                                    });
                                  },
                                  icon: const Icon(Icons.remove, size: 18),
                                  color: primaryBlue,
                                ),
                                Text(
                                  '${line.qty}',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w900,
                                    fontSize: 15,
                                  ),
                                ),
                                IconButton(
                                  visualDensity: VisualDensity.compact,
                                  onPressed: () {
                                    setState(() {
                                      line.qty++;
                                      _step5ReviewContinueEnabled = true;
                                    });
                                  },
                                  icon: const Icon(Icons.add, size: 18),
                                  color: primaryBlue,
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          TextButton.icon(
                            onPressed: () async {
                              final c =
                                  TextEditingController(text: line.name);
                              final ok = await showDialog<bool>(
                                context: context,
                                builder: (ctx) => AlertDialog(
                                  title: const Text('Edit item'),
                                  content: TextField(
                                    controller: c,
                                    decoration: const InputDecoration(
                                        hintText: 'Name'),
                                  ),
                                  actions: [
                                    TextButton(
                                      onPressed: () =>
                                          Navigator.pop(ctx, false),
                                      child: const Text('Cancel'),
                                    ),
                                    FilledButton(
                                      onPressed: () =>
                                          Navigator.pop(ctx, true),
                                      child: const Text('Save'),
                                    ),
                                  ],
                                ),
                              );
                              final t = c.text.trim();
                              c.dispose();
                              if (ok == true && t.isNotEmpty && mounted) {
                                setState(() {
                                  line.name = t;
                                  _step5ReviewContinueEnabled = true;
                                });
                              }
                            },
                            icon: const Icon(Icons.edit_outlined, size: 18),
                            label: const Text('Edit'),
                          ),
                          TextButton.icon(
                            onPressed: () {
                              setState(() {
                                _step5ReviewLines.removeAt(i);
                                if (_step5ReviewLines.isEmpty) {
                                  _step5ReviewContinueEnabled = false;
                                }
                              });
                            },
                            style: TextButton.styleFrom(
                              foregroundColor: Colors.red.shade600,
                            ),
                            icon: const Icon(Icons.delete_outline, size: 18),
                            label: const Text('Delete'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStepSix() {
    const primaryBlue = Color(0xFF2D7DFF);
    final zi = (_addItemsZoneIndex ?? 0).clamp(0, _sections.length - 1);
    final zone = _sections[zi];

    return ColoredBox(
      color: const Color(0xFFF4F7FC),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 12),
            const Text(
              '🐧',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 56),
            ),
            const SizedBox(height: 12),
            const Text(
              'All set!',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.w900,
                color: Color(0xFF1A2B4D),
              ),
            ),
            const SizedBox(height: 10),
            Text(
              'Your $zone is set up. You can add or edit items anytime from the home screen.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 15,
                height: 1.45,
                fontWeight: FontWeight.w600,
                color: Colors.black.withOpacity(0.5),
              ),
            ),
            const SizedBox(height: 24),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: Colors.black.withOpacity(0.06)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 16,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Icon(Icons.celebration_outlined,
                      color: primaryBlue.withOpacity(0.9), size: 32),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'You finished steps 1–6. Tap below to save and start using Friji.',
                      style: TextStyle(
                        fontSize: 13,
                        height: 1.4,
                        fontWeight: FontWeight.w600,
                        color: Colors.black.withOpacity(0.52),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

