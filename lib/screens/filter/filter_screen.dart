import 'package:flutter/material.dart';
import '../../config/colors.dart';
import '../../models/filter_model.dart';
import '../../models/resume_analysis_model.dart';
import '../../services/firestore_service.dart';
import '../../services/resume_service.dart';
import '../../services/location_service.dart';
import '../upload/resume_upload_screen.dart';
import '../scoring/resume_scoring_screen.dart';

class FilterScreen extends StatefulWidget {
  const FilterScreen({super.key});

  @override
  State<FilterScreen> createState() => _FilterScreenState();
}

class _FilterScreenState extends State<FilterScreen> {
  final FirestoreService _firestoreService = FirestoreService();
  final ResumeService _resumeService = ResumeService();
  FilterModel _filters = FilterModel();
  bool _isLoading = true;
  ResumeAnalysisModel? _resumeAnalysis;
  final TextEditingController _locationController = TextEditingController();
  List<String> _locationSuggestions = [];
  
  final List<String> _jobTypes = [
    'Vollzeit',
    'Teilzeit',
    'Praktikum',
    'Freelance',
    'Werkstudent',
  ];
  
  final List<String> _industries = [
    'IT & Software', 'Marketing', 'Sales', 'Finance', 'HR', 'Design', 'Consulting', 'Healthcare', 'Education', 'Engineering',
    'Media', 'Retail', 'Manufacturing', 'Transportation', 'Real Estate',
    'Construction', 'Hospitality', 'Logistics', 'Gastronomie', 'Pflege', 'Verwaltung', 'Öffentlicher Dienst', 'Handwerk',
  ];

  final List<String> _technologies = [
    // breiter: auch nicht-IT Technologien/Tools
    'MS Office', 'Excel', 'Salesforce', 'SAP', 'HubSpot', 'Canva', 'Figma', 'Adobe Photoshop', 'Adobe Illustrator', 'Google Ads', 'Meta Ads',
    // und Entwickler-Stack bleibt enthalten
    'Flutter','React','Vue.js','Angular','Node.js','Python','Java','C#','PHP','Swift','Kotlin','Dart','JavaScript','TypeScript','Go','Rust',
  ];

  final List<String> _companySizes = [
    'Startup (1-10)',
    'Klein (11-50)',
    'Mittel (51-200)',
    'Groß (201-1000)',
    'Konzern (1000+)',
  ];

  final List<String> _benefits = [
    'Homeoffice',
    'Flexible Arbeitszeiten',
    'Kantine',
    'Fitnessstudio',
    'Betriebliche Altersvorsorge',
    'Firmenwagen',
    'Weiterbildung',
    'Urlaubsgeld',
    'Weihnachtsgeld',
    'Beteiligung',
  ];
  
  final List<String> _experienceLevels = [
    'Schüler/Aushilfe',
    'Praktikum',
    'Werkstudent',
    'Junior (0-2J)',
    'Mid (3-5J)',
    'Senior (6-10J)',
    'Expert (10+J)',
    'Quereinstieg',
  ];
  
  final List<String> _contractTypes = [
    'Festanstellung',
    'Befristet',
    'Freelance',
    'Werkstudent',
  ];

  @override
  void initState() {
    super.initState();
    _loadFilters();
    _loadResumeAnalysis();
  }

  Future<void> _loadFilters() async {
    try {
      final savedFilters = await _firestoreService.getFilters();
      if (savedFilters != null) {
        setState(() {
          _filters = savedFilters;
        _isLoading = false;
        });
      } else {
        setState(() => _isLoading = false);
      }
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Fehler beim Laden der Filter: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  Future<void> _loadResumeAnalysis() async {
    try {
      final analysis = await _resumeService.getLatestAnalysis();
      setState(() {
        _resumeAnalysis = analysis;
      });
    } catch (e) {
      // Handle error silently
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Filter & Einstellungen'),
        backgroundColor: AppColors.surface,
        elevation: 0,
        actions: [
          TextButton(
            onPressed: _clearFilters,
            child: const Text('Zurücksetzen'),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Upload Resume Section
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.upload_file,
                          color: AppColors.primary,
                        ),
                        const SizedBox(width: 8),
                        const Text(
                          'Lebenslauf',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Lade deinen Lebenslauf hoch für eine bessere Job-Empfehlung',
                      style: TextStyle(
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (context) => const ResumeUploadScreen(),
                            ),
                          );
                        },
                        icon: const Icon(Icons.upload),
                        label: const Text('Lebenslauf hochladen'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            
            const SizedBox(height: 24),
            
            // Location Filter
            _buildSection(
              title: 'Standort',
              icon: Icons.location_on_outlined,
              child: Column(
                children: [
                  RawAutocomplete<String>(
                    optionsBuilder: (TextEditingValue textEditingValue) {
                      final q = textEditingValue.text.trim().toLowerCase();
                      if (q.isEmpty) return const Iterable<String>.empty();
                      // Vorschläge inkl. Umlaute und Kürzeln (BER → Berlin)
                      final cityMap = {
                        'ber': 'Berlin', 'berlin': 'Berlin',
                        'muc': 'München', 'muenchen': 'München', 'münchen': 'München',
                        'cgn': 'Köln', 'koeln': 'Köln', 'köln': 'Köln',
                        'dus': 'Düsseldorf', 'düsseldorf': 'Düsseldorf',
                        'fra': 'Frankfurt', 'frankfurt': 'Frankfurt',
                        'ham': 'Hamburg', 'hamburg': 'Hamburg',
                        'vie': 'Wien', 'wien': 'Wien',
                        'zrh': 'Zürich', 'zuerich': 'Zürich', 'zürich': 'Zürich',
                        'basel': 'Basel', 'bern': 'Bern', 'graz': 'Graz', 'linz': 'Linz', 'salzburg': 'Salzburg', 'innsbruck': 'Innsbruck',
                      };
                      return cityMap.entries
                          .where((e) => e.key.startsWith(q))
                          .map((e) => e.value)
                          .toSet()
                          .take(8);
                    },
                    onSelected: (String selection) {
                      setState(() {
                        _locationController.text = selection;
                        _filters = _filters.copyWith(location: selection);
                      });
                    },
                    fieldViewBuilder: (context, controller, focusNode, onFieldSubmitted) {
                      return TextFormField(
                        controller: controller,
                        focusNode: focusNode,
                        decoration: const InputDecoration(
                          labelText: 'Stadt oder Region',
                          hintText: 'z.B. München, Berlin, Remote',
                        ),
                        onChanged: (value) {
                          setState(() {
                            _filters = _filters.copyWith(location: value.isEmpty ? null : value);
                          });
                        },
                      );
                    },
                    optionsViewBuilder: (context, onSelected, options) {
                      return Align(
                        alignment: Alignment.topLeft,
                        child: Material(
                          elevation: 4.0,
                          child: ListView(
                            padding: EdgeInsets.zero,
                            shrinkWrap: true,
                            children: options.map((opt) {
                              return ListTile(
                                title: Text(opt),
                                onTap: () => onSelected(opt),
                              );
                            }).toList(),
                          ),
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: Text('Max. Entfernung: ${_filters.maxDistance?.toInt() ?? 50} km'),
                      ),
                      Expanded(
                        child: Slider(
                          value: _filters.maxDistance ?? 50,
                          min: 5,
                          max: 200,
                          divisions: 39,
                          onChanged: (value) {
                            setState(() {
                              _filters = _filters.copyWith(maxDistance: value);
                            });
                          },
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            
            // Salary Filter
            _buildSection(
              title: 'Gehalt',
              icon: Icons.euro_outlined,
              child: Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      decoration: const InputDecoration(
                        labelText: 'Min. Gehalt',
                        hintText: '30000',
                        suffixText: '€',
                      ),
                      keyboardType: TextInputType.number,
                      onChanged: (value) {
                        setState(() {
                          _filters = _filters.copyWith(
                            minSalary: value.isEmpty ? null : double.tryParse(value),
                          );
                        });
                      },
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: TextFormField(
                      decoration: const InputDecoration(
                        labelText: 'Max. Gehalt',
                        hintText: '80000',
                        suffixText: '€',
                      ),
                      keyboardType: TextInputType.number,
                      onChanged: (value) {
                        setState(() {
                          _filters = _filters.copyWith(
                            maxSalary: value.isEmpty ? null : double.tryParse(value),
                          );
                        });
                      },
                    ),
                  ),
                ],
              ),
            ),
            
            // Job Type Filter
            _buildSection(
              title: 'Stellentyp',
              icon: Icons.work_outline,
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _jobTypes.map((type) => _buildChip(
                  label: type,
                  selected: _filters.jobTypes.contains(type),
                  onSelected: (selected) {
                    setState(() {
                      final jobTypes = List<String>.from(_filters.jobTypes);
                      if (selected) {
                        jobTypes.add(type);
                      } else {
                        jobTypes.remove(type);
                      }
                      _filters = _filters.copyWith(jobTypes: jobTypes);
                    });
                  },
                )).toList(),
              ),
            ),
            
            // Remote Work Filter
            _buildSection(
              title: 'Remote-Arbeit',
              icon: Icons.home_outlined,
              child: Row(
                children: [
                  Expanded(
                    child: Text('Min. Remote-Anteil: ${_filters.minRemotePercentage?.toInt() ?? 0}%'),
                  ),
                  Expanded(
                    child: Slider(
                      value: _filters.minRemotePercentage ?? 0,
                      min: 0,
                      max: 100,
                      divisions: 10,
                      onChanged: (value) {
                        setState(() {
                          _filters = _filters.copyWith(minRemotePercentage: value);
                        });
                      },
                    ),
                  ),
                ],
              ),
            ),
            
            // Industry Filter
            _buildSection(
              title: 'Branche',
              icon: Icons.business_outlined,
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _industries.map((industry) => _buildChip(
                  label: industry,
                  selected: _filters.industries.contains(industry),
                  onSelected: (selected) {
                    setState(() {
                      final industries = List<String>.from(_filters.industries);
                      if (selected) {
                        industries.add(industry);
                      } else {
                        industries.remove(industry);
                      }
                      _filters = _filters.copyWith(industries: industries);
                    });
                  },
                )).toList(),
              ),
            ),
            
            // Experience Level Filter
            _buildSection(
              title: 'Erfahrungslevel',
              icon: Icons.trending_up_outlined,
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _experienceLevels.map((level) => _buildChip(
                  label: level,
                  selected: _filters.experienceLevels.contains(level),
                  onSelected: (selected) {
                    setState(() {
                      final levels = List<String>.from(_filters.experienceLevels);
                      if (selected) {
                        levels.add(level);
                      } else {
                        levels.remove(level);
                      }
                      _filters = _filters.copyWith(experienceLevels: levels);
                    });
                  },
                )).toList(),
              ),
            ),
            
            // Technologies Filter
            _buildSection(
              title: 'Technologien',
              icon: Icons.code_outlined,
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _technologies.map((tech) => _buildChip(
                  label: tech,
                  selected: _filters.technologies?.contains(tech) ?? false,
                  onSelected: (selected) {
                    setState(() {
                      final technologies = List<String>.from(_filters.technologies ?? []);
                      if (selected) {
                        technologies.add(tech);
                      } else {
                        technologies.remove(tech);
                      }
                      _filters = _filters.copyWith(technologies: technologies);
                    });
                  },
                )).toList(),
              ),
            ),
            
            // Company Size Filter
            _buildSection(
              title: 'Unternehmensgröße',
              icon: Icons.business_outlined,
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _companySizes.map((size) => _buildChip(
                  label: size,
                  selected: _filters.companySizes?.contains(size) ?? false,
                  onSelected: (selected) {
                    setState(() {
                      final sizes = List<String>.from(_filters.companySizes ?? []);
                      if (selected) {
                        sizes.add(size);
                      } else {
                        sizes.remove(size);
                      }
                      _filters = _filters.copyWith(companySizes: sizes);
                    });
                  },
                )).toList(),
              ),
            ),
            
            // Benefits Filter
            _buildSection(
              title: 'Benefits',
              icon: Icons.card_giftcard_outlined,
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _benefits.map((benefit) => _buildChip(
                  label: benefit,
                  selected: _filters.benefits?.contains(benefit) ?? false,
                  onSelected: (selected) {
                    setState(() {
                      final benefits = List<String>.from(_filters.benefits ?? []);
                      if (selected) {
                        benefits.add(benefit);
                      } else {
                        benefits.remove(benefit);
                      }
                      _filters = _filters.copyWith(benefits: benefits);
                    });
                  },
                )).toList(),
              ),
            ),
            
            const SizedBox(height: 32),
            
            // Apply Filters Button
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                onPressed: _applyFilters,
                child: Text(
                  'Filter anwenden (${_filters.activeFilterCount} aktiv)',
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSection({
    required String title,
    required IconData icon,
    required Widget child,
  }) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: AppColors.primary),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            child,
          ],
        ),
      ),
    );
  }

  Widget _buildChip({
    required String label,
    required bool selected,
    required Function(bool) onSelected,
  }) {
    return FilterChip(
      label: Text(label),
      selected: selected,
      onSelected: onSelected,
      selectedColor: AppColors.primary.withOpacity(0.2),
      checkmarkColor: AppColors.primary,
    );
  }

  void _clearFilters() {
    setState(() {
      _filters = FilterModel();
    });
  }

  void _applyFilters() async {
    try {
      await _firestoreService.saveFilters(_filters);
      if (mounted) Navigator.of(context).pop(); // schließen & Trigger reload im Jobs-Tab
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${_filters.activeFilterCount} Filter gespeichert'),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Fehler beim Speichern: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }
}
