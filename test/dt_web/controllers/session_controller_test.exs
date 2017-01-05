defmodule DtWeb.SessionControllerTest do
  use DtWeb.ConnCase

  setup %{conn: conn} do
    {:ok, conn: put_req_header(conn, "accept", "application/json")}
  end

  test "login must not exist with GET", %{conn: conn} do
    conn = get conn, api_login_path(conn, :create)
    response(conn, 404)
  end

  test "fail login with no params", %{conn: conn} do
    conn = post conn, api_login_path(conn, :create)
    response(conn, 401)
  end

  test "fail login with invalid password", %{conn: conn} do
    conn = post conn, api_login_path(conn, :create), user: %{username: "admin@local", password: "invalid"}
    response(conn, 401)
  end

  test "valid login", %{conn: conn} do
    conn = post conn, api_login_path(conn, :create), user: %{username: "admin@local", password: "password"}
    json = json_response(conn, 200)
    assert json["token"]
  end

  test "cannot refresh without a valid token", %{conn: conn} do
    conn
    |> post(api_login_path(conn, :refresh))
    |> response(401)
  end

  test "refresh token", %{conn: conn} do
    conn = post conn, api_login_path(conn, :create), user: %{username: "admin@local", password: "password"}
    json = json_response(conn, 200)
    jwt_1 = Guardian.decode_and_verify!(json["token"])

    conn = Phoenix.ConnTest.build_conn
    |> put_req_header("accept", "application/json")
    |> put_req_header("authorization", json["token"])
    |> post(api_login_path(conn, :refresh))

    json = json_response(conn, 200)
    jwt_2 = Guardian.decode_and_verify!(json["token"])

    assert jwt_1["exp"] < jwt_2["exp"]
  end

end
