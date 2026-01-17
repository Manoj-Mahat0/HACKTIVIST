import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:indoor_navigation/features/buildings/presentation/bloc/buildings_bloc.dart';
import 'package:indoor_navigation/core/navigation/app_navigator.dart';
import 'package:indoor_navigation/features/navigation/presentation/pages/unified_navigation_page.dart';
import 'package:indoor_navigation/features/navigation/presentation/bloc/navigation_bloc.dart';
import 'package:indoor_navigation/core/di/injection_container.dart';
import 'package:indoor_navigation/core/widgets/connectivity_indicator.dart';

class BuildingsPage extends StatefulWidget {
  const BuildingsPage({super.key});

  @override
  State<BuildingsPage> createState() => _BuildingsPageState();
}

class _BuildingsPageState extends State<BuildingsPage> {
  @override
  void initState() {
    super.initState();
    context.read<BuildingsBloc>().add(LoadBuildingsEvent());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Buildings'),
        actions: const [
          ConnectivityIndicator(showLabel: true),
          SizedBox(width: 16),
        ],
      ),
      body: BlocBuilder<BuildingsBloc, BuildingsState>(
        builder: (context, state) {
          if (state is BuildingsLoadingState) {
            return const Center(child: CircularProgressIndicator());
          } else if (state is BuildingsErrorState) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error, size: 64, color: Colors.red),
                  const SizedBox(height: 16),
                  Text(
                    'Error: ${state.message}',
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () {
                      context.read<BuildingsBloc>().add(LoadBuildingsEvent());
                    },
                    child: const Text('Retry'),
                  ),
                ],
              ),
            );
          } else if (state is BuildingsLoadedState) {
            if (state.buildings.isEmpty) {
              return const Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.business, size: 64, color: Colors.grey),
                    SizedBox(height: 16),
                    Text('No buildings available'),
                    SizedBox(height: 8),
                    Text(
                      'Contact your administrator to add buildings',
                      style: TextStyle(color: Colors.grey),
                    ),
                  ],
                ),
              );
            }

            return RefreshIndicator(
              onRefresh: () async {
                context.read<BuildingsBloc>().add(LoadBuildingsEvent());
              },
              child: ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: state.buildings.length,
                itemBuilder: (context, index) {
                  final building = state.buildings[index];
                  return Card(
                    margin: const EdgeInsets.only(bottom: 16),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              CircleAvatar(
                                backgroundColor: Theme.of(context).colorScheme.primary,
                                child: const Icon(
                                  Icons.business,
                                  color: Colors.white,
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      building.name,
                                      style: Theme.of(context).textTheme.titleLarge,
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      building.address,
                                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                        color: Colors.grey[600],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          if (building.description != null) ...[
                            const SizedBox(height: 12),
                            Text(
                              building.description!,
                              style: Theme.of(context).textTheme.bodyMedium,
                            ),
                          ],
                          const SizedBox(height: 16),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Lat: ${building.latitude.toStringAsFixed(6)}\nLng: ${building.longitude.toStringAsFixed(6)}',
                                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                  color: Colors.grey[600],
                                ),
                              ),
                              ElevatedButton.icon(
                                onPressed: () {
                                  AppNavigator.push(
                                    UnifiedNavigationPage(
                                      building: building,
                                    ),
                                  );
                                },
                                icon: const Icon(Icons.navigation),
                                label: const Text('Navigate'),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            );
          }

          return const SizedBox.shrink();
        },
      ),
    );
  }
}