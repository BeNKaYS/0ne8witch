import Foundation
import Darwin

/// Sistem CPU ve Bellek (RAM) durumunu hafif bir şekilde izleyen yönetici
public final class SystemMonitor: ObservableObject {
    public static let shared = SystemMonitor()
    
    @Published public var cpuUsageText: String = "--%"
    @Published public var memoryUsageText: String = "--%"
    @Published public var memoryUsedGBText: String = "-- GB"
    
    private var timer: Timer?
    private var previousCpuInfo: processor_info_array_t?
    private var previousCpuInfoCount: mach_msg_type_number_t = 0
    
    private init() {
        updateStats()
    }
    
    public func startMonitoring() {
        stopMonitoring()
        updateStats()
        timer = Timer.scheduledTimer(withTimeInterval: 3.0, repeats: true) { [weak self] _ in
            self?.updateStats()
        }
    }
    
    public func stopMonitoring() {
        timer?.invalidate()
        timer = nil
    }
    
    public func updateStats() {
        updateCPU()
        updateMemory()
    }
    
    private func updateCPU() {
        var numProcessors: natural_t = 0
        var processorInfo: processor_info_array_t?
        var numProcessorInfo: mach_msg_type_number_t = 0
        
        let result = host_processor_info(
            mach_host_self(),
            PROCESSOR_CPU_LOAD_INFO,
            &numProcessors,
            &processorInfo,
            &numProcessorInfo
        )
        
        guard result == KERN_SUCCESS, let cpuInfo = processorInfo else { return }
        
        if let prevInfo = previousCpuInfo {
            var totalInUse: Int64 = 0
            var totalTotal: Int64 = 0
            
            for i in 0..<Int(numProcessors) {
                let inUse = Int64(cpuInfo[Int(CPU_STATE_MAX) * i + Int(CPU_STATE_USER)] - prevInfo[Int(CPU_STATE_MAX) * i + Int(CPU_STATE_USER)])
                    + Int64(cpuInfo[Int(CPU_STATE_MAX) * i + Int(CPU_STATE_SYSTEM)] - prevInfo[Int(CPU_STATE_MAX) * i + Int(CPU_STATE_SYSTEM)])
                    + Int64(cpuInfo[Int(CPU_STATE_MAX) * i + Int(CPU_STATE_NICE)] - prevInfo[Int(CPU_STATE_MAX) * i + Int(CPU_STATE_NICE)])
                let total = inUse + Int64(cpuInfo[Int(CPU_STATE_MAX) * i + Int(CPU_STATE_IDLE)] - prevInfo[Int(CPU_STATE_MAX) * i + Int(CPU_STATE_IDLE)])
                
                totalInUse += inUse
                totalTotal += total
            }
            
            if totalTotal > 0 {
                let usage = (Double(totalInUse) / Double(totalTotal)) * 100.0
                cpuUsageText = String(format: "%%%0.0f", min(100.0, max(0.0, usage)))
            }
            
            let prevSize = vm_size_t(previousCpuInfoCount) * vm_size_t(MemoryLayout<integer_t>.size)
            vm_deallocate(mach_task_self_, vm_address_t(bitPattern: prevInfo), prevSize)
        }
        
        previousCpuInfo = cpuInfo
        previousCpuInfoCount = numProcessorInfo
    }
    
    private func updateMemory() {
        var vmStats = vm_statistics64()
        var count = mach_msg_type_number_t(MemoryLayout<vm_statistics64>.size / MemoryLayout<integer_t>.size)
        
        let hostPort = mach_host_self()
        let result = withUnsafeMutablePointer(to: &vmStats) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                host_statistics64(hostPort, HOST_VM_INFO64, $0, &count)
            }
        }
        
        guard result == KERN_SUCCESS else { return }
        
        let pageSize = UInt64(vm_kernel_page_size)
        let active = UInt64(vmStats.active_count) * pageSize
        let wire = UInt64(vmStats.wire_count) * pageSize
        let compressed = UInt64(vmStats.compressor_page_count) * pageSize
        let used = active + wire + compressed
        
        let total = ProcessInfo.processInfo.physicalMemory
        if total > 0 {
            let pct = (Double(used) / Double(total)) * 100.0
            let usedGB = Double(used) / 1_073_741_824.0
            let totalGB = Double(total) / 1_073_741_824.0
            memoryUsageText = String(format: "%%%0.0f", min(100.0, max(0.0, pct)))
            memoryUsedGBText = String(format: "%.1f/%.0f GB", usedGB, totalGB)
        }
    }
    
    deinit {
        stopMonitoring()
        if let prevInfo = previousCpuInfo {
            let prevSize = vm_size_t(previousCpuInfoCount) * vm_size_t(MemoryLayout<integer_t>.size)
            vm_deallocate(mach_task_self_, vm_address_t(bitPattern: prevInfo), prevSize)
        }
    }
}
