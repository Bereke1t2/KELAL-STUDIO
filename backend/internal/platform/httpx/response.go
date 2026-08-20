// Package httpx holds the shared HTTP plumbing: the JSON response writers every
// handler uses and the router constructor. It depends only on apperror + gin —
// NOT on the middleware subpackage or any feature — so middleware and features
// can depend on it without an import cycle.
package httpx

import (
	"net/http"

	"github.com/gin-gonic/gin"

	"github.com/Bereke1t2/KELAL-STUDIO/backend/internal/platform/apperror"
)

// OK writes 200 with a JSON body.
func OK(c *gin.Context, body any) { c.JSON(http.StatusOK, body) }

// Created writes 201 with a JSON body.
func Created(c *gin.Context, body any) { c.JSON(http.StatusCreated, body) }

// Accepted writes 202 with a JSON body (async: video generation returns a Job).
func Accepted(c *gin.Context, body any) { c.JSON(http.StatusAccepted, body) }

// JSON writes an explicit status with a JSON body.
func JSON(c *gin.Context, status int, body any) { c.JSON(status, body) }

// Empty writes a status with no body.
func Empty(c *gin.Context, status int) { c.Status(status) }

// Fail renders any error as the contract-shaped ErrorResponse (openapi.yaml)
// and aborts the handler chain. Non-apperror errors become an opaque 500. The
// error is also recorded on the gin context (c.Error) so the logging middleware
// can record its real cause without leaking it to the client.
func Fail(c *gin.Context, err error) {
	ae := apperror.From(err)
	_ = c.Error(ae)
	c.AbortWithStatusJSON(ae.HTTPStatus, ae.Response())
}
