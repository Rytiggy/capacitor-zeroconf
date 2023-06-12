import Network

class ServiceManager {
    private var services: [Service] = []
    
    // Add a new service to the array
    func addService(_ service: Service) {
        services.append(service)
    }
    
    // Remove a service by name
    func removeServiceByName(_ name: String) {
        services.removeAll { $0.name == name }
    }
    
    // Update a service
    func updateService(_ updatedService: Service) {
        if let index: Array<Service>.Index = services.firstIndex(where: { $0.name == updatedService.name }) {
            services[index] = updatedService
        }
    }
    
    // Get all services
    func getAllServices() -> [Service] {
        return services
    }
}


public struct Service {
    var domain: String
    var type: String
    var name: String
    var port: UInt16?
    var hostName: NWEndpoint
    var ipv4Addresses: [String]
    var ipv6Addresses: [String]
    var txtRecord: [String: String]
    
    init(
        domain: String,
        type: String,
        name: String,
        port: UInt16?,
        hostName: NWEndpoint,
        ipv4Addresses: [String],
        ipv6Addresses: [String],
        txtRecord: [String: String]
    ) {
        self.domain = domain
        self.type = type
        self.name = name
        self.port = port
        self.hostName = hostName
        self.ipv4Addresses = ipv4Addresses
        self.ipv6Addresses = ipv6Addresses
        self.txtRecord = txtRecord
    }
    
    // Getters and Setters (Computed Properties)
    
    var fullAddress: String {
        "\(hostName):\(port)"
    }
    
    var hasIPv4: Bool {
        !ipv4Addresses.isEmpty
    }
    
    var hasIPv6: Bool {
        !ipv6Addresses.isEmpty
    }
    
    // Additional methods can be added here
    
}

