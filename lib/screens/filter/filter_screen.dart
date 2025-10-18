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
    'IT & Software',
    'Marketing & Werbung',
    'Sales & Vertrieb',
    'Finance & Banking',
    'HR & Personalwesen',
    'Design & Kreativ',
    'Consulting & Beratung',
    'Healthcare & Medizin',
    'Bildung & Training',
    'Engineering & Technik',
    'Media & Kommunikation',
    'Retail & Handel',
    'Manufacturing & Produktion',
    'Transportation & Logistik',
    'Real Estate & Immobilien',
    'Gastronomie & Hotel',
    'Bau & Handwerk',
    'Automotive & Fahrzeug',
    'Energie & Umwelt',
    'Telekommunikation',
    'Recht & Justiz',
    'Versicherung',
    'Pharma & Biotech',
    'Aerospace & Luftfahrt',
    'Entertainment & Events',
    'Non-Profit & Sozial',
    'Landwirtschaft',
    'Mining & Rohstoffe',
    'Tourismus & Reisen',
    'Sport & Fitness',
  ];

  final List<String> _technologies = [
    // IT & Development
    'Flutter', 'React', 'Vue.js', 'Angular', 'Node.js', 'Python', 'Java', 'C#', 'PHP', 'Swift', 'Kotlin', 'Dart', 'JavaScript', 'TypeScript', 'Go', 'Rust',
    // Marketing & Sales
    'Google Ads', 'Facebook Ads', 'SEO', 'SEM', 'Social Media', 'Content Marketing', 'Email Marketing', 'Analytics', 'CRM', 'Salesforce',
    // Design & Creative
    'Photoshop', 'Illustrator', 'Figma', 'Sketch', 'InDesign', 'After Effects', 'Premiere Pro', 'Canva', 'Adobe XD',
    // Business & Finance
    'Excel', 'PowerBI', 'Tableau', 'SAP', 'QuickBooks', 'Xero', 'Accounting', 'Financial Analysis', 'Budgeting',
    // Healthcare & Medical
    'Medical Software', 'EMR', 'HIPAA', 'Clinical Research', 'Medical Devices', 'Pharmaceutical', 'Healthcare IT',
    // Engineering & Technical
    'AutoCAD', 'SolidWorks', 'MATLAB', 'LabVIEW', 'PLC Programming', 'SCADA', 'Industrial Automation',
    // Languages & Communication
    'German', 'English', 'French', 'Spanish', 'Italian', 'Portuguese', 'Chinese', 'Japanese', 'Russian', 'Arabic',
    // Soft Skills
    'Project Management', 'Leadership', 'Team Management', 'Communication', 'Problem Solving', 'Analytical Thinking',
    // Industry Specific
    'CAD', 'CAM', 'CNC', 'Welding', 'Machining', 'Quality Control', 'Supply Chain', 'Logistics', 'Procurement',
    // Other Skills
    'Driving License', 'Forklift License', 'Safety Training', 'First Aid', 'CPR', 'Teaching', 'Training', 'Coaching',
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
    'Keine Erfahrung',
    '0-1 Jahre',
    '1-2 Jahre',
    '2-3 Jahre',
    '3-5 Jahre',
    '5-7 Jahre',
    '7-10 Jahre',
    '10+ Jahre',
    'Student',
    'Praktikant',
    'Werkstudent',
    'Berufseinsteiger',
    'Erfahren',
    'Senior',
    'Expert',
    'Manager',
    'Director',
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
                      // erweiterte Vorschläge inkl. Umlaute
                      final cities = [
                        // Deutschland
                        'Berlin', 'München', 'Köln', 'Düsseldorf', 'Frankfurt', 'Hamburg', 'Stuttgart', 'Leipzig', 'Dresden', 'Nürnberg', 'Bremen', 'Hannover', 'Duisburg', 'Bochum', 'Wuppertal', 'Bielefeld', 'Bonn', 'Mannheim', 'Karlsruhe', 'Augsburg', 'Wiesbaden', 'Mönchengladbach', 'Gelsenkirchen', 'Braunschweig', 'Chemnitz', 'Kiel', 'Aachen', 'Halle', 'Magdeburg', 'Freiburg', 'Krefeld', 'Lübeck', 'Oberhausen', 'Erfurt', 'Mainz', 'Rostock', 'Kassel', 'Hagen', 'Hamm', 'Saarbrücken', 'Mülheim', 'Potsdam', 'Ludwigshafen', 'Oldenburg', 'Leverkusen', 'Osnabrück', 'Solingen', 'Heidelberg', 'Herne', 'Neuss', 'Darmstadt', 'Paderborn', 'Regensburg', 'Ingolstadt', 'Würzburg', 'Fürth', 'Wolfsburg', 'Offenbach', 'Ulm', 'Heilbronn', 'Pforzheim', 'Göttingen', 'Bottrop', 'Trier', 'Recklinghausen', 'Reutlingen', 'Bremerhaven', 'Koblenz', 'Bergisch Gladbach', 'Jena', 'Remscheid', 'Erlangen', 'Moers', 'Siegen', 'Hildesheim', 'Salzgitter',
                        // Österreich
                        'Wien', 'Graz', 'Linz', 'Salzburg', 'Innsbruck', 'Klagenfurt', 'Villach', 'Wels', 'Sankt Pölten', 'Dornbirn', 'Steyr', 'Wiener Neustadt', 'Feldkirch', 'Bregenz', 'Leonding', 'Wolfsberg', 'Baden', 'Klosterneuburg', 'Leoben', 'Krems', 'Traun', 'Amstetten', 'Kapfenberg', 'Mödling', 'Hallein', 'Kufstein', 'Traiskirchen', 'Schwechat', 'Braunau am Inn', 'Spittal an der Drau', 'Saalfelden', 'Ansfelden', 'Tulln', 'Hohenems', 'Ternitz', 'Kornenburg', 'Neunkirchen', 'Hard', 'Vöcklabruck', 'Lustenau', 'Brunn am Gebirge', 'Ried im Innkreis', 'Seekirchen', 'Marchtrenk', 'Gmunden', 'Villach', 'Wattens', 'Kitzbühel', 'Zell am See', 'Bad Ischl', 'Hall in Tirol', 'Imst', 'Lienz', 'Sankt Johann im Pongau', 'Bischofshofen', 'Radstadt', 'Mittersill', 'Oberndorf', 'Neumarkt am Wallersee', 'Obertrum', 'Seekirchen', 'Straßwalchen', 'Mattsee', 'Henndorf', 'Eugendorf', 'Thalgau', 'Hof bei Salzburg', 'Kuchl', 'Golling', 'Abtenau', 'Werfen', 'Radstadt', 'Altenmarkt', 'Flachau', 'Wagrain', 'St. Johann im Pongau', 'Bischofshofen', 'Mühlbach', 'Dienten', 'Hüttau', 'Werfenweng', 'Eben im Pongau', 'Filzmoos', 'Untertauern', 'Kleinarl', 'Sankt Veit im Pongau', 'Göriach', 'Hüttschlag', 'Tweng', 'Muhr', 'Ramingstein', 'Thomatal', 'Krakaudorf', 'Krakauebene', 'Mariapfarr', 'Tamsweg', 'Mauterndorf', 'Sankt Michael im Lungau', 'Unternberg', 'Sankt Margarethen im Lungau', 'Weißpriach', 'Zederhaus', 'Sankt Andrä im Lungau', 'Ramingstein', 'Thomatal', 'Krakaudorf', 'Krakauebene', 'Mariapfarr', 'Tamsweg', 'Mauterndorf', 'Sankt Michael im Lungau', 'Unternberg', 'Sankt Margarethen im Lungau', 'Weißpriach', 'Zederhaus', 'Sankt Andrä im Lungau',
                        // Schweiz
                        'Zürich', 'Genf', 'Basel', 'Bern', 'Lausanne', 'Winterthur', 'Luzern', 'St. Gallen', 'Lugano', 'Biel', 'Thun', 'Köniz', 'La Chaux-de-Fonds', 'Fribourg', 'Schaffhausen', 'Vernier', 'Chur', 'Uster', 'Sion', 'Neuchâtel', 'Lancy', 'Zug', 'Kriens', 'Rapperswil-Jona', 'Schwyz', 'Frauenfeld', 'Wil', 'Dietikon', 'Baar', 'Riehen', 'Carouge', 'Kreuzlingen', 'Uzwil', 'Wädenswil', 'Montreux', 'Bulle', 'Martigny', 'Aarau', 'Herisau', 'Burgdorf', 'Zofingen', 'Olten', 'Solothurn', 'Burgdorf', 'Thun', 'Spiez', 'Interlaken', 'Grindelwald', 'Lauterbrunnen', 'Mürren', 'Wengen', 'Adelboden', 'Lenk', 'Gstaad', 'Saanen', 'Château-d\'Oex', 'Rougemont', 'Rossinière', 'L\'Etivaz', 'Château-d\'Oex', 'Rougemont', 'Rossinière', 'L\'Etivaz', 'Château-d\'Oex', 'Rougemont', 'Rossinière', 'L\'Etivaz',
                        // Spezielle Suchbegriffe
                        'Remote', 'Homeoffice', 'Hybrid', 'Deutschland', 'Österreich', 'Schweiz', 'DACH', 'Europa', 'Weltweit',
                      ];
                      return cities.where((c) => c.toLowerCase().startsWith(q)).take(8);
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
