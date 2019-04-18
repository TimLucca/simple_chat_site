defmodule WebServer do
    require Logger 

    def accept(port) do
        {:ok, socket} = :gen_tcp.listen(port, [:binary, packet: :line, active: false, reuseaddr: true])
        Logger.info "Accepting connections on port: #{port}"
        loop_acceptor(socket)
    end 

    defp loop_acceptor(socket) do 
        {:ok, client} = :gen_tcp.accept(socket)
        Logger.info "Connected"
        Task.start_link(fn -> serve(client) end)
        loop_acceptor(socket)
    end 

    defp serve(socket) do  
        socket |> read_line() |> write_line(socket)
        :ok = :gen_tcp.close(socket)
        Logger.info "Connection closed"
    end 

    defp read_line(socket) do 
        case :gen_tcp.recv(socket, 0) do 
            {:ok, data} -> data 
            {:error, reason} -> {:error, reason}
        end
    end 

    defp write_line(line, socket) when is_tuple(line) do 
        {:error, reason} = line
        Logger.info "Error: #{reason}"
    end 

    defp write_line(line, socket) do 
        Logger.info "Request: #{line}"
        :gen_tcp.send(socket, proc_req(socket, line)) 
    end 

    defp proc_req(socket, line) do 
        [req, page, prot] = String.split(line, " ")
        cond do 
            req == "GET" -> get_req(socket, page, prot)
            req == "POST" -> post_req(socket, page, prot)
            req == "FETCH" -> fetch_req(socket, page, prot)
        end
    end

    defp get_req(socket, page, prot) do
        {status_code, status, file} = get_file(String.replace_prefix(page, "/", ""))
        {type, ext} = get_file_info(file)
        send_header(socket, String.replace(prot, "\r\n", ""), status_code, status, type, ext)
        file_data(file)
    end 

    defp post_req(socket, page, prot) do 
        send_header(socket, String.replace(prot, "\r\n", ""), 200, "OK", "text", "plain")
        write_data(String.replace_prefix(page, "/", ""))
    end 

    defp fetch_req(socket, page, prot) do
        send_header(socket, String.replace(prot, "\r\n", ""), 200, "OK", "text", "txt")
        file_data(String.replace_prefix(page, "/", ""))
    end

    defp get_file(page) do
        cond do 
            page == "" -> {200, "OK", "index.html"}
            File.exists?(page) -> {200, "OK", page} 
            true -> {404, "Not Found", "404.html"}
        end 
    end 

    defp get_file_info(file) do 
        [name, ext] = String.split(file, ".")
        cond do
            Enum.member?(["html", "css"], ext) -> {"text", ext}
            ext == "js" -> {"text", "javascript"}
            Enum.member?(["jpg", "png", "gif", "jpg"], ext) -> {"image", ext}
            true -> {"unknown", ext}
        end 
    end 

    defp send_header(socket, prot, status_code, status, type, ext) do
        {{year, mon, day}, _} = :calendar.local_time()
        :gen_tcp.send(socket, "#{prot} #{status_code} #{status}\n")
        :gen_tcp.send(socket, "Date: #{mon}/#{day}/#{year}\n")
        :gen_tcp.send(socket, "Server: Elixier Server : 0.01\n")
        :gen_tcp.send(socket, "Content-type: #{type}/#{ext}\n\n")
    end

    defp file_data(name) do
        {:ok, file} = File.open(name)
        data = IO.binread(file, :all)
        :ok = File.close(file)
        data
    end 

    defp write_data(page) do 
        cond do 
            page == "flush" -> File.write("chat.txt", "")
            true -> File.write("chat.txt", String.replace_prefix(String.replace(page, "%20", " "), "", "<br>"), [:append])
        end
        ""
    end

    def main(args \\ []) do 
        accept(9999)
    end 
end