//
//  LocationRepository.swift
//  MAGE
//
//  Created by Dan Barela on 8/8/24.
//  Copyright © 2024 National Geospatial Intelligence Agency. All rights reserved.
//

import Foundation
import Combine

private struct LocationRepositorySourceProviderKey: InjectionKey {
    static var currentValue: LocationRepository = LocationRepository()
}

extension InjectedValues {
    var locationRepository: LocationRepository {
        get { Self[LocationRepositorySourceProviderKey.self] }
        set { Self[LocationRepositorySourceProviderKey.self] = newValue }
    }
}

class LocationRepository: ObservableObject {
    @Injected(\.locationLocalDataSource)
    var localDataSource: LocationLocalDataSource
    
    var refreshPublisher: AnyPublisher<Date, Never>? {
        refreshSubject?.eraseToAnyPublisher()
    }
    
    var cancellable = Set<AnyCancellable>()

    var refreshSubject: PassthroughSubject<Date, Never>? = PassthroughSubject<Date, Never>()
    
    init() {
        UserDefaults.standard.publisher(for: \.locationTimeFilter)
            .removeDuplicates()
            .sink { [weak self] order in
                NSLog("locationTimeFilter update: \(order)")
                Task { [weak self] in
                    self?.refreshSubject?.send(Date())
                }
            }
            .store(in: &cancellable)
        UserDefaults.standard.publisher(for: \.locationTimeFilterUnit)
            .removeDuplicates()
            .sink { [weak self] order in
                NSLog("locationTimeFilterUnit update: \(order)")
                Task { [weak self] in
                    self?.refreshSubject?.send(Date())
                }
            }
            .store(in: &cancellable)
        UserDefaults.standard.publisher(for: \.locationTimeFilterNumber)
            .removeDuplicates()
            .sink { [weak self] order in
                NSLog("locationTimeFilterNumber update: \(order)")
                Task { [weak self] in
                    self?.refreshSubject?.send(Date())
                }
            }
            .store(in: &cancellable)
    }
    
    func observeLatestFiltered() -> AnyPublisher<Date, Never>? {
        localDataSource.observeLatestFiltered()
    }
    
    func locations(
        userIds: [String]? = nil,
        paginatedBy paginator: Trigger.Signal? = nil
    ) -> AnyPublisher<[URIItem], Error> {
        localDataSource.locations(userIds: userIds, paginatedBy: paginator)
    }
    
    func getLocation(locationUri: URL) async -> LocationModel? {
        await localDataSource.getLocation(uri: locationUri)
    }
    
    func observeLocation(locationUri: URL) -> AnyPublisher<LocationModel, Never>? {
        localDataSource.observeLocation(locationUri: locationUri)
    }
}
