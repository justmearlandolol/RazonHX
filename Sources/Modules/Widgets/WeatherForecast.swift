import Foundation

struct WeatherForecast: Decodable {
    struct Current: Decodable {
        let time: String
        let temperature_2m: Double
        let weather_code: Int
        let relative_humidity_2m: Int
        let wind_speed_10m: Double
    }
    struct Hourly: Decodable {
        let time: [String]
        let temperature_2m: [Double]
        let precipitation_probability: [Int?]
    }
    let current: Current
    let hourly: Hourly

    var nextHours: [(String, Double)] {
        let start = hourly.time.firstIndex(where: { $0 >= current.time }) ?? 0
        return zip(hourly.time, hourly.temperature_2m).dropFirst(start).prefix(7).map {
            (String($0.0.suffix(5)), $0.1)
        }
    }

    var precipitation: Int? {
        let roundedHour = String(current.time.prefix(13)) + ":00"
        guard let index = hourly.time.firstIndex(of: roundedHour), hourly.precipitation_probability.indices.contains(index) else { return nil }
        return hourly.precipitation_probability[index]
    }

    static func fetch(_ location: DesktopConfiguration.Weather, completion: @escaping (WeatherForecast?) -> Void) -> URLSessionDataTask? {
        var request = URLComponents(string: "https://api.open-meteo.com/v1/forecast")!
        request.queryItems = [
            URLQueryItem(name: "latitude", value: String(location.latitude)),
            URLQueryItem(name: "longitude", value: String(location.longitude)),
            URLQueryItem(name: "current", value: "temperature_2m,weather_code,relative_humidity_2m,wind_speed_10m"),
            URLQueryItem(name: "hourly", value: "temperature_2m,precipitation_probability"),
            URLQueryItem(name: "timezone", value: "auto"),
            URLQueryItem(name: "forecast_days", value: "2")
        ]
        guard let url = request.url else { return nil }
        let task = URLSession.shared.dataTask(with: URLRequest(url: url, timeoutInterval: 12)) { data, response, _ in
            let value: WeatherForecast?
            if (response as? HTTPURLResponse)?.statusCode == 200, let data = data, data.count <= 128_000 {
                value = try? JSONDecoder().decode(Self.self, from: data)
            } else { value = nil }
            DispatchQueue.main.async { completion(value) }
        }
        task.resume()
        return task
    }
}
